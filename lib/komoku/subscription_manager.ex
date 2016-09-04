defmodule Komoku.SubscriptionManager do
  
  use GenServer

  def start_link, do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def subscribe(name), do: GenServer.call(__MODULE__, {:subscribe, name})
  def unsubscribe(name), do: GenServer.call(__MODULE__, {:unsubscribe, name})
  def unsubscribe_all(pid) when is_pid(pid), do: GenServer.call(__MODULE__, {:unsubscribe_all, pid})
  def unsubscribe_all(name), do: GenServer.call(__MODULE__, {:unsubscribe_all, name})
  def publish(%{key: _key, time: _time} = change), do: GenServer.cast(__MODULE__, {:publish, change})
  def stats, do: GenServer.call(__MODULE__, :stats)

  def init(_) do
    # TODO setup periodical msg to cleanup dead processes
    :timer.send_interval(120_000, :cleanup)
    {:ok, %{}}
  end

  def handle_info(:cleanup, subs), do: {:noreply, subs |> cleanup}

  def handle_call({:subscribe, name}, {pid, _ref}, subs) do
    {:reply, :ok, 
      subs |> Map.put(name, (subs[name] || []) ++ [pid])
    }
  end

  def handle_call({:unsubscribe, name}, {pid, _ref}, subs) do
    {:reply, :ok, 
      subs |> Map.put(name,
        (subs[name] || []) |> Enum.filter(fn pid_ -> pid_ != pid end)
      )
    }
  end

  # Remove all subscrptions for given process
  def handle_call({:unsubscribe_all, pid}, _from, subs) when is_pid(pid) do
    {:reply, :ok, 
      subs |> Enum.map(fn {key, pids} ->
        {key, pids |> Enum.filter(fn pid_ -> pid_ != pid end)}
      end)
      |> Enum.into(%{})
    }
  end

  # Remove all subscriptinos for given key
  def handle_call({:unsubscribe_all, name}, _from, subs) do
    {:reply, :ok, subs |> Map.delete(name)}
  end

  def handle_call(:stats, _from, subs) do
    stats = subs |> cleanup |> Enum.map(fn {key, pids} ->
      {key, pids |> Enum.count}
    end) |> Enum.into(%{})
    {:reply, stats, subs}
  end


  def handle_cast({:publish, change}, subs) do
    (subs[change.key] || []) |> Enum.each(fn pid ->
      send(pid, {:key_update, change})
    end)
    {:noreply, subs}
  end

  defp cleanup(subs) do
    subs 
      # Remove dead processes
      |> Enum.map(fn {key, pids} ->
        {key, pids |> Enum.filter(&Process.alive?/1)}
      end)
      # Remove keys without subscriptions
      |> Enum.filter(fn {_key, pids} -> length(pids) > 0 end)
      |> Enum.into(%{})
  end

end
