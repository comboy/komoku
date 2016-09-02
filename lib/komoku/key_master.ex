defmodule Komoku.KeyMaster do
  alias Komoku.Storage.Repo
  alias Komoku.Storage.Schema.Key

  use GenServer

  def start_link, do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  def get(name), do: GenServer.call __MODULE__, {:get, name}
  def insert(name, type, opts \\ %{}), do: GenServer.call __MODULE__, {:insert, name, type, opts}
  def update(name, type, opts \\ %{}), do: GenServer.call __MODULE__, {:update, name, type, opts}
  def delete(name), do: GenServer.call __MODULE__, {:delete, name}
  def handler(name), do: GenServer.call __MODULE__, {:handler, name}
  def list, do: GenServer.call __MODULE__, :list

  # Implementation

  def init(_) do
    send(self, :do_init) # Do init in your own process to make system boot  quicker
    {:ok, nil}
  end

  def handle_info(:do_init, _) do
    keys = Key
      |> Repo.all
      |> Enum.map(fn %Key{type: type, name: name, id: id, opts: opts} ->
        params = %{type: type, id: id, opts: opts} |> prepare_opts
        case type do
          "uptime" -> # For uptime keys we need to spawn handlers right away in case they need updates
            {name, params |> Map.put(:handler, spawn_handler(name, params))}
           _ ->
            {name, params}
        end
      end)
      |> Enum.into(%{})
    {:noreply, keys}
  end

  # Fetch key
  # PONDER {:ok, key} and :not_found instead of nil?
  def handle_call({:get, name}, _from, keys), do: {:reply, keys[name], keys}

  # Insert a new key
  def handle_call({:insert, name, type, opts}, _from, keys) do
    # TODO handle case when the key is already present and type matches, should return OK
    changeset = Key.changeset(%Key{}, %{name: name |> to_string, type: type, opts: opts})
    case Repo.insert(changeset) do
      {:ok, key} ->
        {:reply, :ok, keys |> Map.put(name, %{type: key.type, id: key.id, opts: opts} |> prepare_opts) }
      {:error, error} ->
        # TODO abstact error messages away from ecto. We probably want
        # * {:error, :invalid_key_name}
        # * {:error, :already_exists}
        # * {:error, :invalid opts} later?
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
        dbkey = Repo.get!(Key, key.id) # TODO we shouldn't need to do this select first
        dbkey = dbkey |> Ecto.Changeset.change(opts: key.opts |> Map.merge(opts))
        case Repo.update(dbkey) do
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
  def handle_call({:delete, name}, _from, cache) do
    case cache[name] do
      nil -> # key is not present
        {:reply, :ok, cache} # sure bro, I deleted it (I guess there's no need for an error)
      %{type: _type, id: id} = key ->
        # * remove all existing data points
        #   should be done with ecto has_many
        # * kill handler if present
        key[:handler] && GenServer.stop(key[:handler], :normal)
        # * remove subscriptions
        # PONDER: key is removed then key with the same name is added, perhaps processes that subscribed to this name changes still want to hear about them
        # Komoku.SubscriptionManager.unsubscribe_all(name)
        Key |> Repo.get(id) |> Repo.delete
        {:reply, :ok, cache |> Map.delete(name)}
    end
  end

  # List all keys
  def handle_call(:list, _from, cache), do: {:reply, cache, cache}

  # Return pid of the process handling given key
  def handle_call({:handler, name}, _from, keys) do
    case keys[name] do
      nil ->
        {:reply, nil, keys}
      %{handler: handler} ->
        {:reply, handler, keys}
      params ->
        handler = spawn_handler(name, params)
        {:reply, handler, keys |> Map.put(name, keys[name] |> Map.put(:handler, handler))}
    end
  end

  defp spawn_handler(name, params) do
    # TODO this needs to go through supervision tree, and key handler process failure can't brink down key master
    {:ok, pid} = Komoku.KeyHandler.start_link(name, params)
    pid
  end

  defp prepare_opts(params), do: params |> Map.put(:opts, default_opts(params) |> Map.merge(params[:opts] || %{}))

  defp default_opts(%{type: "uptime"} = _opts), do: base_default_opts |> Map.merge(%{"max_time" => 60})
  defp default_opts(_params), do: base_default_opts

  defp base_default_opts do
    %{
      same_value_resolution: 60,
      min_resolution: 1
    }
  end
end
