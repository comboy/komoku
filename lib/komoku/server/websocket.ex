defmodule Komoku.Server.Websocket do

  defmodule Handler do
    @behaviour :cowboy_websocket_handler
    require Logger

    def init({_tcp, _http}, _req, _opts) do
      {:upgrade, :protocol, :cowboy_websocket}
    end

    def websocket_init(_transport, req, _opts) do
      {:ok, req, :undefined_state}
    end

    def websocket_terminate(_reason, _req, _state), do: :ok

    def websocket_handle({:text, content}, req, state) do
      {reply, state} = case Poison.decode(content) do
        {:ok, query} ->
          # authontication query will need separate case so that it can modify the state
          {handle_query(query), state}
        {:error, _} ->
          {%{error: "invalid_json"}, state}
      end
      {:reply, {:text, reply |> Poison.encode!}, req, state}
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

  def start_link do
    # TODO we need ssl, cert files should be an option in config.exis
    dispatch = :cowboy_router.compile([
      { :_, # all hostnames
        [{"/", Handler, []}]
      }
    ])

    ws_config = Application.fetch_env!(:komoku, :websocket_server)

    port = ws_config[:port]
    ssl = ws_config[:ssl]

    case ssl do
      true ->
        :cowboy.start_https(:http, 100, [
          port: port,
          certfile: ws_config[:cert_file],
          keyfile: ws_config[:key_file],
        ], [
          env: [dispatch: dispatch]
        ])
      _ ->
        :cowboy.start_http(:http, 100, [port: port], [env: [dispatch: dispatch]])
    end
  end


end
