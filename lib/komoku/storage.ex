defmodule Komoku.Storage do
  alias Komoku.Storage.Repo
  alias Komoku.Util
  #alias Komoku.Storage.Schema.Key
  alias Komoku.Storage.Schema.DataNumeric
  alias Komoku.Storage.Schema.DataBoolean
  alias Komoku.Storage.KeyManager, as: KM


  def start_link do
    # TODO would love to know how to get rid of this from here,
    # test_helper gets evaluated after the application is already started
    if Mix.env == :test do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
      Ecto.Adapters.SQL.Sandbox.mode(Komoku.Storage.Repo, {:shared, self()})
    end

    import Supervisor.Spec

    children = [
      worker(KM, [])
    ]
    opts = [strategy: :one_for_one, name: Komoku.Storage.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def insert_key(name, type), do: KM.insert(name, type)
  def list_keys, do: KM.list

  def put(name, value) do
    # TODO this should be happening in the key process
    case KM.get(name) do
      nil ->
        {:error, :key_not_found} # TODO guess key type and insert it
      key ->
        params = %{value: value, key_id: key.id, time: Ecto.DateTime.utc(:usec)}
        changeset = case key.type do
          "numeric" ->
            DataNumeric.changeset(%DataNumeric{}, params)
          "boolean" ->
            DataBoolean.changeset(%DataBoolean{}, params)
        end
        case Repo.insert(changeset) do
          {:ok, _dN} -> :ok
          {:error, error} -> {:error, error}
        end
    end
  end

  def get(name) do
    case last(name) do
      nil -> nil
      {value, _time} -> value
    end
  end

  def last(name) do
    import Ecto.Query

    case KM.get(name) do
      nil ->
        nil
      key ->
        # TODO case by key type
        data_type = case key.type do
          "numeric" -> DataNumeric
          "boolean" -> DataBoolean
        end
        query = from p in data_type,
          where: p.key_id == ^key.id, 
          order_by: [desc: p.time],
          order_by: [desc: p.id],
          limit: 1
        case query |> Repo.one do
          nil -> nil
          data -> {data.value, data.time |> Util.ecto_to_ts}
        end
    end
  end

end
