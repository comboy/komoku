defmodule Komoku.Server do
  # TODO
  # Point of access to the values
  # Manages genservers for specific values, also starts engine (eg database workers pool)
  # Represents public API
  # * put, get etc
  #
  # Should it also start e.g. websocket server
  # It would be nice if it was not a genserver to avoid bottleneck

  alias Komoku.KeyMaster
  alias Komoku.KeyHandler
  alias Komoku.SubscriptionManager

  alias Komoku.Util

  def start_link do
    import Supervisor.Spec

    opts = [strategy: :one_for_one, name: Komoku.Server.Supervisor]

    servers = Application.fetch_env!(:komoku, :servers)
      |> Enum.map(fn {server_type, config} ->
        case server_type do
          :websocket ->
            #Komoku.Server.Websocket.start_link(config) |> IO.inspect
            supervisor(Komoku.Server.Websocket, [config], id: "websocket_#{config[:port]}")
        end
      end)

    children = [ supervisor(Komoku.KeyMaster.Supervisor, []) | servers]

    Supervisor.start_link(children, opts)
  end

  # TODO find a good place to put doc about types and opts (some opts are common)
  #
  # Add a new key. TODO proper docs, here are available opts to have them in one place:
  # * same_value_resolution - update to key with same value won't be stored in db until time difference is greater than this value [seconds, can be float]
  # * min_resolution - if multiple values will be pushed within that time, only one value will be stored in db [seconds, can be float] - we probably want e.g. averaging for numeric
  #
  # type specific:
  # * uptime
  # ** max_time - time after which value automatically goes to false [seconds, can be float]
  def insert_key(name, type, opts \\ %{}) do
    op_count(:insert_key)
    KeyMaster.insert(name, type, opts)
  end

  def update_key(name, type, opts \\ %{}) do
    op_count(:update_key)
    KeyMaster.update(name, type, opts)
  end

  def delete_key(name) do
    op_count(:delete_key)
    KeyMaster.delete(name)
  end

  def list_keys do
    op_count(:list_keys)
    KeyMaster.list |> Enum.map(fn {key, opts} ->
      {key, opts |> Map.delete(:handler)}
    end)
    |> Enum.into(%{})
  end

  def put(name, value), do: put(name, value, Util.ts)

  def put(name, value, time) do
    case KeyMaster.handler(name) do
      nil ->
        case guess_type(value) do
          "unknown" ->
            {:error, :unknown_value_type}
          type ->
            insert_key(name, type)
            put(name, value, time)
        end
      handler ->
        op_count(:put)
        handler |> KeyHandler.put(value, time)
    end
  end

  def get(name) do
    op_count(:get)
    case get_last(name) do
      nil -> nil
      {value, _time} -> value
    end
  end

  def last(name) do
    op_count(:last)
    get_last(name)
  end

  def subscribe(key), do: SubscriptionManager.subscribe(key)
  def unsubscribe(key), do: SubscriptionManager.unsubscribe(key)

  def increment(name, step \\ 1, time \\ Komoku.Util.ts) do
    op_count(:increment)
    case KeyMaster.handler(name) do
      nil -> {:error, :invalid_key}
      pid ->  KeyHandler.increment(pid, step, time)
    end
  end

  def decrement(name, step \\ 1, time \\ Komoku.Util.ts) do
    op_count(:decrement)
    case KeyMaster.handler(name) do
      nil -> {:error, :invalid_key}
      pid ->  KeyHandler.decrement(pid, step, time)
    end
  end

  defp guess_type(value) when is_number(value), do: "numeric"
  defp guess_type(value) when is_boolean(value), do: "boolean"
  defp guess_type("true"), do: "boolean"
  defp guess_type("false"), do: "boolean"
  defp guess_type(str) when is_binary(str), do: "string"
  defp guess_type(_), do: "unknown"

  defp op_count(name) do
    Komoku.Stats.increment(:server_op_count, name)
  end

  defp get_last(name) do
    case KeyMaster.handler(name) do
      nil -> nil
      pid ->  KeyHandler.last(pid)
    end
  end

end
