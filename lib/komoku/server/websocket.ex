defmodule Komoku.Server.Websocket do

  defmodule Handler do
    require Logger

    @behaviour :cowboy_websocket_handler

    def init({_tcp, _http}, _req, _opts) do
      {:upgrade, :protocol, :cowboy_websocket}
    end

    def websocket_init(_transport, req, _opts) do
      {:ok, req, :undefined_state}
    end

    def websocket_terminate(_reason, _req, _state), do: :ok

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

    def handle_query(%{"get" => %{"key" => key}}), do: Komoku.Storage.get(key)

    def handle_query(%{"put" => %{"key" => key, "value" => value} = data}) do
      :ok = Komoku.Storage.put(key, value, data["time"] || Komoku.Util.ts)
      :ack
    end

    def handle_query(%{"keys" => _opts}) do
      Komoku.Storage.list_keys
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
            case Komoku.Storage.update_key(name, type, params["opts"] || %{}) do
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

  require Logger

  def init(config) do
    start_link(config)
  end

  def start_link(config) do
    dispatch = :cowboy_router.compile([
      { :_, # all hostnames
        [{"/", Handler, []}]
      }
    ])

    port = config[:port]

    Logger.info "Starting websocket server on port #{port} [ssl=#{!!config[:ssl]}]"

    case config[:ssl] do
      true ->
        :cowboy.start_https("webscocket_https_#{port}", 100, [
          port: port,
          certfile: config[:cert_file],
          keyfile: config[:key_file],
        ], [
          env: [dispatch: dispatch]
        ])
      _ ->
        :cowboy.start_http("websocket_http_#{port}", 100, [port: port], [env: [dispatch: dispatch]])
    end
  end


end
