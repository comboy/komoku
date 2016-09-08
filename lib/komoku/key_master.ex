defmodule Komoku.KeyMaster do

  alias Komoku.Storage

  use GenServer

  def start_link, do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  def get(name), do: GenServer.call __MODULE__, {:get, name}
  def insert(name, type, opts \\ %{}), do: GenServer.call __MODULE__, {:insert, name, type, opts}
  def update(name, type, opts \\ %{}), do: GenServer.call __MODULE__, {:update, name, type, opts}
  def delete(name), do: GenServer.call __MODULE__, {:delete, name}
  def handler(name), do: GenServer.call __MODULE__, {:handler, name}
  def list, do: GenServer.call __MODULE__, :list
  def stats, do: GenServer.call __MODULE__, :stats

  # Implementation

  def init(_) do
    send(self, :do_init) # Do init in your own process to make system boot  quicker
    {:ok, nil}
  end

  def handle_info(:do_init, _) do
    keys = Storage.list_keys
      |> Enum.map(fn (%{id: _id, name: name, type: _type} = params) ->
        {name, params |> prepare_opts}
      end)
      |> Enum.into(%{})
      # For uptime keys we need to spawn handlers right away in case they need updates
      |> start_uptime_key_handlers
    {:noreply, keys}
  end

  # Fetch key
  # PONDER {:ok, key} and :not_found instead of nil?
  def handle_call({:get, name}, _from, keys), do: {:reply, keys[name], keys}

  # Insert a new key
  def handle_call({:insert, name, type, opts}, _from, keys) do
    # TODO handle case when the key is already present and type matches, should return OK
    case Storage.create_key(%{name: name |> to_string, type: type, opts: opts}) do
      {:ok, key} ->
        {:reply, :ok, keys |> Map.put(name, %{type: key.type, id: key.id, opts: opts} |> prepare_opts) }
      {:error, error} ->
        {:reply, {:error, error}, keys}
    end
  end

  def handle_call({:update, name, type, opts}, from, keys) do
    case keys[name] do
      nil ->
        # Key does'nt exist, just insert it
        handle_call({:insert, name, type, opts}, from, keys)
      %{type: ^type} = key ->
        # Type is fine, we just need to update the opts
        # TODO opts validation, not sure if it belongs in Schema.Key changeset or somewhere in KM
        # TODO remove opts that match defaults not to store them in db
        case Storage.update_key_opts(key.id, key.opts |> Map.merge(opts)) do
          {:ok, key_} ->
            {:reply, :ok, keys |> Map.put(name, key |> Map.put(:opts, key_.opts))}
          {:error, error} ->
            # TODO abstract away ecto errors, see :insert
            {:reply, {:error, error}, keys}
        end
      _ ->
        # Cannot modify key type
        {:reply, {:error, :type_mismatch}, keys}
    end
  end

  # Delete a key
  def handle_call({:delete, name}, _from, keys) do
    case keys[name] do
      nil -> # key is not present
        {:reply, :ok, keys} # sure bro, I deleted it (I guess there's no need for an error)
      %{type: _type, id: id} ->
        # * remove all existing data points
        #   should be done with ecto has_many
        # * kill handler if present
        case handler_pid(name) do
          :undefined -> :ok
          _pid -> Komoku.KeyMaster.Supervisor.stop_kh(name)
        end
        # * remove subscriptions
        # PONDER: key is removed then key with the same name is added, perhaps processes that subscribed to this name changes still want to hear about them
        # Komoku.SubscriptionManager.unsubscribe_all(name)
        :ok = Storage.delete_key(id)
        {:reply, :ok, keys |> Map.delete(name)}
    end
  end

  # List all keys
  def handle_call(:list, _from, keys), do: {:reply, keys, keys}

  # Return pid of the process handling given key
  def handle_call({:handler, name}, _from, keys) do
    case keys[name] do
      nil ->
        {:reply, nil, keys}
      params ->
        case handler_pid(name) do
          :undefined ->
            pid = spawn_handler(name, params)
            {:reply, pid, keys}
          pid ->
            {:reply, pid, keys}
        end
    end
  end

  def handle_call(:stats, _from, keys) do
    {total, active} = keys |> Enum.reduce({0,0}, fn ({name, _params}, {total, active}) ->
      case handler_pid(name) do
        :undefined -> {total + 1, active}
        _pid -> {total + 1, active + 1}
      end
    end)
    {:reply, %{total: total, active: active}, keys}
  end

  defp spawn_handler(name, params) do
    {:ok, pid} = Komoku.KeyMaster.Supervisor.start_kh(name, params)
    pid
  end

  defp handler_pid(name), do: {:n, :l, {:kh, name}} |> :gproc.whereis_name

  defp prepare_opts(params), do: params |> Map.put(:opts, default_opts(params) |> Map.merge(params[:opts] || %{}))

  defp default_opts(%{type: "uptime"} = _opts), do: base_default_opts |> Map.merge(%{"max_time" => 60})
  defp default_opts(_params), do: base_default_opts

  defp base_default_opts do
    %{
      same_value_resolution: 60,
      min_resolution: 1
    }
  end

  defp start_uptime_key_handlers(keys) do
    keys
      |> Enum.filter(fn {_name, params} -> params[:type] == "uptime" end)
      |> Enum.each(fn {name, params} ->
        if handler_pid(name) == :undefined do
          spawn_handler(name, params)
        end
      end)
    keys
  end
end
