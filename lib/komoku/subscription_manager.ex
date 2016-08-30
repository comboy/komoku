defmodule Komoku.SubscriptionManager do
  
  use GenServer

  def start_link, do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def subscribe(name), do: GenServer.call(__MODULE__, {:subscribe, name})
  # TODO def unsubscribe(name), do: GenServer.call(__MODULE__, {:unsubscribe, name})
  # TODO def unsubscribe_all(pid), do: GenServer.call(__MODULE__, {:unsubscribe_all, name})
  def publish(%{key: _key, time: _time} = change), do: GenServer.cast(__MODULE__, {:publish, change})

  def init(_) do
    # TODO setup periodical msg to cleanup dead processes
    {:ok, %{}}
  end

  def handle_call({:subscribe, name}, {pid, ref}, subs) do
    {:reply, :ok, 
      subs |> Map.put(name, (subs[name] || []) ++ [pid])
    }
  end

  def handle_cast({:publish, change}, subs) do
    (subs[change.key] || []) |> Enum.each(fn pid ->
      send(pid, {:key_update, change})
    end)
    {:noreply, subs}
  end

end
