defmodule Komoku.KeyHandler do
  # TODO ponder: separate handler modules for different data types? this would  probably require some handy macros to keep it DRY
  alias Komoku.Storage.Repo
  alias Komoku.Storage.Schema.DataNumeric
  alias Komoku.Storage.Schema.DataBoolean
  alias Komoku.Storage.Schema.DataString
  alias Komoku.Util

  use GenServer

  def start_link(name, opts), do: GenServer.start_link(__MODULE__, opts |> Map.put(:name, name))
  # get the last stored value and time tuple
  def last(pid), do: GenServer.call pid, :last
  # get the last stored value
  def get(pid), do: GenServer.call pid, :get
  # get the last stored value
  def put(pid, value, time), do: GenServer.call pid, {:put, value, time}

  # Implementation

  def init(key), do: {:ok, key}
  # get with last value cached
  def handle_call(:last, _from, %{last: last} = key), do: {:reply, last, key}
  # get when we don't yet have the cache
  def handle_call(:last, _from, key) do
    last = get_last_from_db(key)
    {:reply, last, key |> Map.put(:last, last)}
  end

  def handle_call(:get, from, key) do
    {:reply, last, key} = handle_call(:last, from, key) # is it cool to call another handle_call? ¯\_(ツ)_/¯
    value = case last do
      nil -> nil
      {value, _time} -> value
    end
    {:reply, value, key}
  end

  def handle_call({:put, value, time}, from, key) do
    value = value |> cast(key)
    {:reply, previous, key} = handle_call(:get, from, key) # TODO not cool after all, move it some function
    Komoku.SubscriptionManager.publish(%{key: key[:name], value: value, previous: previous, time: time}) # FIXME previous
    # TODO we probably want to put it async in some task,
    # then in case it fails one time we switch to sync
    params = %{value: value, key_id: key.id, time: time |> Util.ts_to_ecto}
    # TODO key.type to module time helper in some place to DRY
    changeset = case key.type do
      "numeric" ->
        DataNumeric.changeset(%DataNumeric{}, params)
      "boolean" ->
        DataBoolean.changeset(%DataBoolean{}, params)
      "string" ->
        DataString.changeset(%DataString{}, params)
    end
    ret = case Repo.insert(changeset) do
      {:ok, _dN} -> :ok
      {:error, error} -> {:error, error}
    end
    {:reply, ret, key |> update_last({value, time})}
  end

  # We only want to update last if it doesn't have the highest time anymore
  defp update_last(key, {value, time}) do
    case key[:last] do
      nil -> 
        key |> Map.put(:last, {value, time})
      {_prev_value, prev_time} ->
        if prev_time > time do
          key
        else
          key |> Map.put(:last, {value, time})
        end
    end
  end

  defp cast("true", %{type: "boolean"}), do: true
  defp cast("false", %{type: "boolean"}), do: false
  defp cast(value, _key), do: value

  # Retrieve last value and time from DB
  defp get_last_from_db(key) do
    import Ecto.Query
    data_type = case key.type do
      "numeric" -> DataNumeric
      "boolean" -> DataBoolean
      "string" -> DataString
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
