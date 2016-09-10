# Websocket API version 2
defmodule Komoku.Server.Websocket.HandlerV2 do

  @behaviour :cowboy_websocket_handler

  require Logger

  alias Komoku.Stats

  def init({_tcp, _http}, _req, _opts) do
    {:upgrade, :protocol, :cowboy_websocket}
  end

  def websocket_init(_transport, req, opts) do
    Stats.increment(:clients_count, opts[:name])
    {:ok, req, %{opts: opts}}
  end

  def websocket_terminate(_reason, _req, %{opts: opts}) do
    Stats.decrement(:clients_count, opts[:name])
    :ok
  end

  def websocket_handle({:text, content}, req, state) do
    Logger.debug "#{self |> inspect} > #{content}"
    {reply, state} = case Poison.decode(content) do
      {:ok, query} ->
        # authontication query will need separate case so that it can modify the state
        {query |> handle_query |> wrap_result |> append_query_id(query), state}
      {:error, _} ->
        {%{error: "invalid_json"}, state}
    end
    reply_text = reply |> Poison.encode!
    Logger.debug "#{self |> inspect} < #{reply_text}"
    {:reply, {:text, reply_text}, req, state}
  end

  def websocket_handle(data, _req, _state), do: IO.puts "oh we got #{data |> inspect}"

  # updates for subscribed keys
  def websocket_info({:key_update, change}, req, state) do
    {:reply, {:text, %{pub: change} |> Poison.encode!}, req, state}
  end

  def handle_query(%{"get" => %{"key" => key}}) do
    {:ok, Komoku.Server.get(key)}
  end

  def handle_query(%{"put" => %{"key" => key, "value" => value} = data}) do
    Komoku.Server.put(key, value, data["time"] || Komoku.Util.ts)
  end

  def handle_query(%{"last" => %{"key" => key}}) do
    result = case Komoku.Server.last(key) do
      {value, time} -> %{value: value, time: time}
      nil -> nil
    end
    {:ok, result}
  end


  def handle_query(%{"keys" => _opts}) do
    {:ok, Komoku.Server.list_keys}
  end

  def handle_query(%{"sub" => %{"key" => key}}) do
    Komoku.SubscriptionManager.subscribe(key)
  end

  def handle_query(%{"unsub" => %{"key" => key}}) do
    Komoku.SubscriptionManager.unsubscribe(key)
  end

  def handle_query(%{"define" => defs}) do
    defs |> Enum.reduce(:ok, fn({name, params}, status) ->
      case params do
        %{"type" => type} ->
          case Komoku.Server.update_key(name, type, params["opts"] || %{}) do
            :ok -> status
            _   -> {:error, :error_creating_key}
          end
        _ ->
          {:error, :type_not_provided}
      end
    end)
  end

  def handle_query(_), do: {:error, :invalid_query}

  defp wrap_result(value) do
    case value do
      :ok -> %{result: "ok"}
      {:ok, value} -> %{result: value}
      {:error, error} -> %{error: error}
    end
  end

  # If query_id param is provided we include it in the answer.
  # This is to allow parallel execution of multiple queries without mixing the results
  defp append_query_id(result, %{"query_id" => query_id}), do: result |> Map.put(:query_id, query_id)
  defp append_query_id(result, _query), do: result
end
