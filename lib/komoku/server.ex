defmodule Komoku.Server do
  # TODO 
  # Point of access to the values
  # Manages genservers for specific values, also starts engine (eg database workers pool)
  # Represents public API
  # * put, get etc
  #
  # Should it also start e.g. websocket server
  # It would be nice if it was not a genserver to avoid bottleneck

  alias Komoku.KeyMaster, as: KM # TODO KM and KH look too much alike, use different aliases
  alias Komoku.KeyHandler, as: KH
  alias Komoku.Util

  def start_link do
    import Supervisor.Spec

    opts = [strategy: :one_for_one, name: Komoku.Server.Supervisor]

    Application.fetch_env!(:komoku, :servers)
      |> Enum.map(fn {server_type, config} ->
        case server_type do
          :websocket ->
            #Komoku.Server.Websocket.start_link(config) |> IO.inspect
            supervisor(Komoku.Server.Websocket, [config], id: "websocket_#{config[:port]}")
        end
      end)
      |> Supervisor.start_link(opts)
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
  def insert_key(name, type, opts \\ %{}), do: KM.insert(name, type, opts)
  def update_key(name, type, opts \\ %{}), do: KM.update(name, type, opts)

  def delete_key(name), do: KM.delete(name)

  def list_keys do
    KM.list |> Enum.map(fn {key, opts} ->
      {key, opts |> Map.delete(:handler)}
    end)
    |> Enum.into(%{})
  end

  def put(name, value), do: put(name, value, Util.ts)

  def put(name, value, time) do
    case KM.handler(name) do
      nil ->
        case guess_type(value) do
          "unknown" ->
            {:error, :unknown_value_type}
          type ->
            insert_key(name, type)
            put(name, value, time)
        end
      handler ->
        handler |> KH.put(value, time)
    end
  end

  def get(name) do
    case last(name) do
      nil -> nil
      {value, _time} -> value
    end
  end

  def last(name) do
    case KM.handler(name) do
      nil -> nil
      pid ->  KH.last(pid)
    end
  end

  defp guess_type(value) when is_number(value), do: "numeric"
  defp guess_type(value) when is_boolean(value), do: "boolean"
  defp guess_type("true"), do: "boolean"
  defp guess_type("false"), do: "boolean"
  defp guess_type(str) when is_binary(str), do: "string"
  defp guess_type(_), do: "unknown"

  
end
