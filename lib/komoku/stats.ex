defmodule Komoku.Stats do

  use GenServer

  def start_link, do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def increment(group_key, key), do: GenServer.cast __MODULE__, {:increment, group_key, key}
  def decrement(group_key, key), do: GenServer.cast __MODULE__, {:decrement, group_key, key}
  def get(key), do: GenServer.call __MODULE__, {:get, key}
  def get(key1, key2), do: GenServer.call __MODULE__, {:get, key1, key2}

  def init(_) do
    stats = %{}
    opts = %{}
    {:ok, {stats, opts}}
  end

  def handle_cast({:decrement, group_key, key}, {stats, opts}) do
    gk = stats[group_key] || %{}
    k = gk[key] || 0
    {:noreply, {stats |> Map.put(group_key, gk |> Map.put(key, k - 1)), opts}}
  end

  def handle_cast({:increment, group_key, key}, {stats, opts}) do
    gk = stats[group_key] || %{}
    k = gk[key] || 0
    {:noreply, {stats |> Map.put(group_key, gk |> Map.put(key, k + 1)), opts}}
  end

  def handle_call({:get, key}, _from, {stats, opts}) do
    {:reply, stats[key], {stats, opts}}
  end

  def handle_call({:get, key1, key2}, _from, {stats, opts}) do
    {:reply, (stats[key1] || %{})[key2], {stats, opts}}
  end

end
