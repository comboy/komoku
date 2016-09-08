defmodule Komoku.KeyHandler do

  # TODO ponder: separate handler modules for different data types? this would  probably require some handy macros to keep it DRY

  alias Komoku.Storage

  use GenServer

  def start_link(name, opts), do: GenServer.start_link(__MODULE__, opts |> Map.put(:name, name))
  # get the last stored value and time tuple
  def last(pid), do: GenServer.call pid, :last
  # get the last stored value
  def get(pid), do: GenServer.call pid, :get
  # get the last stored value
  def put(pid, value, time), do: GenServer.call pid, {:put, value, time}

  # FIXME I think HK won't receive info about updated opts, it should handle updating opts itself maybe

  # Implementation
  def init(key) do
    :gproc.reg({:n, :l, {:kh, key[:name]}})
    type_init(key)
  end

  def type_init(%{type: "uptime"} = key) do
    send(self, :uptime_init)
    {:ok, key}
  end
  def type_init(key), do: {:ok, key}

  def handle_info(:uptime_init, key) do
    key = key |> Map.put(:last, Storage.last(key))
    key = case key[:last] do
      # If uptim key in the database has true value then update it to false or shedule a msg that will do that
      {true, time} ->
        dt = Komoku.Util.ts - time
        if dt > key.opts["max_time"] do
          {:ok, key} = put_value(true, Komoku.Util.ts, key)
          key
        else
          Process.send_after(self, {:uptime_timeout, time}, ((key.opts["max_time"] - dt) * 1000) |> round)
          key
        end
      _ -> key
    end
    {:noreply, key}
  end

  def handle_info({:uptime_timeout, time}, %{last: {_value, last_time}} = key) do
    cond do
      last_time == time ->
        {:ok, key} = put_value(false, Komoku.Util.ts, key)
        {:noreply, key}
      true ->
        {:noreply, key}
    end
  end

  def handle_call(:last, _from, key) do
    {last, key} = key |> get_last
    {:reply, last, key}
  end

  def handle_call(:get, _from, key) do
    {value, key} = key |> get_value
    {:reply, value, key}
  end

  def handle_call({:put, value, time}, _from, key) do
    {ret, key} = put_value(value, time, key)
    {:reply, ret, key}
  end

  # last value cached
  defp get_last(%{last: last} = key), do: {last, key}
  # when we don't yet have the cache for last value
  defp get_last(key) do
    last = Storage.last(key)
    {last, key |> Map.put(:last, last)}
  end

  defp get_value(key) do
    {last, key} = key |> get_last
    value = case last do
      nil -> nil
      {value, _time} -> value
    end
    {value, key}
  end

  defp put_value(value, time, key) do
    value = value |> cast(key)
    {{pvalue, ptime}, key} = case key |> get_last do
      {nil, key} -> {{nil, nil}, key}
      ok -> ok
    end

    Komoku.SubscriptionManager.publish(%{key: key[:name], value: value, previous: pvalue, time: time})

    ret = cond do
      key.opts[:same_value_resolution] && ptime && pvalue == value && (time - ptime) < key.opts[:same_value_resolution] ->
        :ok
      key.opts[:min_resolution] && ptime && (time - ptime) < key.opts[:min_resolution] ->
        :ok
      true ->
        # TODO we probably want to put it async in some task,
        # then in case it fails one time we switch to sync
        case Storage.put(key, value, time) do
          {:ok, _dN} -> :ok
          {:error, error} -> {:error, error}
        end
    end
    key = key |> update_last({value, time}) |> key_updated
    {ret, key}
  end

  # When uptime key is set to true we need to setup msg to switch it back to false later
  def key_updated(%{type: "uptime", last: {true, time}, opts: %{"max_time" => max_time}} = key) do
    Process.send_after(self, {:uptime_timeout, time}, (max_time * 1000) |> round)
    key
  end

  def key_updated(key), do: key


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

end
