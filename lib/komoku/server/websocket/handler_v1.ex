defmodule Komoku.Server.Websocket.HandlerV1 do

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
        {handle_query(query), state}
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

  def handle_query(%{"get" => %{"key" => key}}), do: Komoku.Server.get(key)

  def handle_query(%{"put" => %{"key" => key, "value" => value} = data}) do
    case Komoku.Server.put(key, value, data["time"] || Komoku.Util.ts) do
      :ok -> :ack
      {:error, error}  -> %{error: error}
    end
  end

  def handle_query(%{"last" => %{"key" => key}}) do
    case Komoku.Server.last(key) do
      {value, time} -> %{value: value, time: time}
      nil -> nil
    end
  end


  def handle_query(%{"keys" => _opts}) do
    Komoku.Server.list_keys
  end

  def handle_query(%{"sub" => %{"key" => key}}) do
    :ok = Komoku.SubscriptionManager.subscribe(key)
    :ack
  end

  def handle_query(%{"unsub" => %{"key" => key}}) do
    :ok = Komoku.SubscriptionManager.unsubscribe(key)
    :ack
  end

  def handle_query(%{"define" => defs}) do
    # PONDER not sure it's worth doing the status, we need to handle exceptions anyway somehew
    # NEWAPI we probably want to provide hash of results for each key definition?
    status = defs |> Enum.reduce(:ok, fn({name, params}, status) ->
      case params do
        %{"type" => type} ->

          # Backwards compatibility
          params = if params["max_time"] do
            params |> Map.put("opts", (params["opts"] || %{}) |> Map.put("max_time", params["max_time"]))
          else
            params
          end

          case Komoku.Server.update_key(name, type, params["opts"] || %{}) do
            :ok -> status
            _   -> :error_creating_key
          end
        _ ->
          :type_not_provided
      end
    end)
    case status do
      :ok -> :ack
      err -> {:error, err}
    end
  end

  def handle_query(_), do: :invalid_query

end
