defmodule Komoku.Storage do

  alias Komoku.Storage.Repo
  alias Komoku.Storage.Schema.DataNumeric
  alias Komoku.Storage.Schema.DataBoolean
  alias Komoku.Storage.Schema.DataString
  alias Komoku.Storage.Schema.Key

  alias Komoku.Util

  # TODO would love to know how to get rid of this from here,
  # We need this preparation for test, it must go after repo start and before servers start
  defmodule TestPrep do
    if Mix.env == :test do
      def start_link do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Komoku.Storage.Repo)
      Ecto.Adapters.SQL.Sandbox.mode(Komoku.Storage.Repo, {:shared, self()})
      {:ok, self}
    end
    else
      def start_link, do: {:ok, self}
    end
  end

def start_link do
  import Supervisor.Spec

  children = [
    supervisor(Repo, []),
    worker(TestPrep, []),
    ]
    opts = [strategy: :one_for_one, name: Komoku.Storage.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def create_key(%{type: type, name: name, opts: opts}) do
    case data_type(type) do
      :invalid -> {:error, :invalid_type}
      _ ->
        changeset = Key.changeset(%Key{}, %{name: name |> to_string, type: type, opts: opts})
        # TODO abstact error messages away from ecto. We probably want
        # * {:error, :invalid_key_name}
        # * {:error, :already_exists}
        # * {:error, :invalid opts} later?
        Repo.insert(changeset)
    end
  end

  def update_key_opts(id, opts) do
    dbkey = Repo.get!(Key, id) # TODO we shouldn't need to do this select first
    dbkey = dbkey |> Ecto.Changeset.change(opts: opts)
    Repo.update(dbkey)
  end

  def delete_key(id) do
    {:ok, _key} = Key |> Repo.get(id) |> Repo.delete
    :ok
  end

  def list_keys do
    Key
      |> Repo.all
      |> Enum.map(fn %Key{type: type, name: name, id: id, opts: opts} ->
        %{type: type, id: id, opts: opts, name: name}
      end)
  end

  def put(%{id: id, type: type} = _key, value, time) do
    params = %{value: value, key_id: id, time: time |> Util.ts_to_ecto}
    data_changeset(type, params) |> Repo.insert |> wrap_ecto_errors
  end

  # Get last value for given key. Returns tuple {value, time} or nil
  # TODO since fetch returns {time, value} tuples it may be better to return the same kind of tuple here for consistency, ie reverse the order
  def last(%{id: id, type: type} = _key) do
    import Ecto.Query
    query = from p in data_type(type),
      where: p.key_id == ^id,
      order_by: [desc: p.time],
      order_by: [desc: p.id], # ensures storage order even if time would be the same for two records
      limit: 1
    case query |> Repo.one do
      nil -> nil
      data -> {data.value, data.time |> Util.ecto_to_ts}
    end
  end

  # TODO better name
  def fetch(%{id: id, type: type} = _key, %{"last" => n} = _opts) do
    import Ecto.Query
    (from p in data_type(type),
      where: p.key_id == ^id,
      order_by: [desc: p.time],
      order_by: [desc: p.id],
      limit: ^n)
    |> Repo.all |> Enum.map(fn x ->
      {x.time |> Util.ecto_to_ts, x.value}
    end)
  end

  defp data_type("numeric"), do: DataNumeric
  defp data_type("counter"), do: DataNumeric
  defp data_type("boolean"), do: DataBoolean
  defp data_type("uptime"),  do: DataBoolean
  defp data_type("string"),  do: DataString
  defp data_type(_), do: :invalid

  defp data_changeset("numeric", params), do: DataNumeric.changeset(%DataNumeric{}, params)
  defp data_changeset("counter", params), do: DataNumeric.changeset(%DataNumeric{}, params)
  defp data_changeset("boolean", params), do: DataBoolean.changeset(%DataBoolean{}, params)
  defp data_changeset("uptime", params),  do: DataBoolean.changeset(%DataBoolean{}, params)
  defp data_changeset("string", params),  do: DataString.changeset(%DataString{}, params)

  defp wrap_ecto_errors(result) do
    case result do
      {:ok, key} ->
        {:ok, key}
      {:error, %{errors: errors} = changeset} ->
        {:error,
          cond do
            errors[:value] && (errors[:value] |> elem(0)) == "is invalid" ->
              :invalid_value
            true ->
              changeset # uknown error
          end
        }
    end
  end

end

