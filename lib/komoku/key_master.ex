defmodule Komoku.KeyMaster do
  alias Komoku.Storage.Repo
  alias Komoku.Storage.Schema.Key

  use GenServer

  def start_link, do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  def get(name), do: GenServer.call __MODULE__, {:get, name}
  def insert(name, type), do: GenServer.call __MODULE__, {:insert, name, type}
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
      |> Enum.map(fn %Key{type: type, name: name, id: id} ->
        {name, %{type: type, id: id}}
      end)
      |> Enum.into(%{})
    {:ok, keys}
  end

  # Fetch key
  # PONDER {:ok, key} and :not_found instead of nil? 
  def handle_call({:get, name}, _from, cache), do: {:reply, cache[name], cache}

  # Insert a new key
  def handle_call({:insert, name, type}, _from, cache) do
    # TODO handle case when the key is already present and type matches, should return OK
    changeset = Key.changeset(%Key{}, %{name: name |> to_string, type: type})
    case Repo.insert(changeset) do
      {:ok, key} ->
        {:reply, :ok, cache |> Map.put(name, %{type: key.type, id: key.id}) }
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
      %{type: _type, id: id} ->
        # TODO remove all existing data points
        # TODO kill kthe key handler if present
        # TODO probably also something with subscripbtions
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
      opts ->
        handler = spawn_handler(name, opts)
        {:reply, handler, keys |> Map.put(name, keys[name] |> Map.put(:handler, handler))}
    end
  end

  defp spawn_handler(name, opts) do
    # TODO this needs to go through supervision tree, and key handler process failure can't brink down key master
    {:ok, pid} = Komoku.KeyHandler.start_link(name, opts)
    pid
  end
end
