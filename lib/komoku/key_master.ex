defmodule Komoku.KeyMaster do
  alias Komoku.Storage.Repo
  alias Komoku.Storage.Schema.Key

  use GenServer

  def start_link, do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  def get(name), do: GenServer.call __MODULE__, {:get, name}
  def insert(name, type, opts \\ %{}), do: GenServer.call __MODULE__, {:insert, name, type, opts}
  def delete(name), do: GenServer.call __MODULE__, {:delete, name}
  def handler(name), do: GenServer.call __MODULE__, {:handler, name}
  def list, do: GenServer.call __MODULE__, :list
  # TODO update for opts
  # TODO opts returned in get and accepted in insert

  # impl

  def init(_) do

    # TODO do the trick with sending myself a cast to avoid lagging init while loading all the keys
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
    {:ok, keys}
  end

  # Fetch key
  # PONDER {:ok, key} and :not_found instead of nil?
  def handle_call({:get, name}, _from, cache), do: {:reply, cache[name], cache}

  # Insert a new key
  def handle_call({:insert, name, type, opts}, _from, cache) do
    # TODO handle case when the key is already present and type matches, should return OK
    changeset = Key.changeset(%Key{}, %{name: name |> to_string, type: type, opts: opts})
    case Repo.insert(changeset) do
      {:ok, key} ->
        {:reply, :ok, cache |> Map.put(name, %{type: key.type, id: key.id, opts: opts} |> prepare_opts) }
      {:error, error} ->
        # TODO abstact error messages away from ecto. We probably want
        # * {:error, :invalid_key_name}
        # * {:error, :already_exists}
        # * {:error, :invalid opts} later?
        {:reply, {:error, error}, cache}
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

  defp default_opts(%{type: "uptime"} = _opts), do: %{"max_time" => 60}
  defp default_opts(_params), do: %{}
end
