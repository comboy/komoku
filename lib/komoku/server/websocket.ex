defmodule Komoku.Server.Websocket do

  require Logger

  def start_link(config) do
    port = config[:port]
    name = config[:name] || "websocket_#{port}"

    handler = case config[:api_version] do
      2 -> Komoku.Server.Websocket.HandlerV2
      _ -> Komoku.Server.Websocket.HandlerV1
    end

    dispatch = :cowboy_router.compile([
      { :_, # all hostnames
        [{"/", handler, [%{name: name}]}]
      }
    ])

    Logger.info "Starting websocket server on port #{port} [ssl=#{!!config[:ssl]}]"

    case config[:ssl] do
      true ->
        :cowboy.start_https(name, 100, [
          port: port,
          certfile: config[:cert_file],
          keyfile: config[:key_file],
        ], [
          env: [dispatch: dispatch]
        ])
      _ ->
        :cowboy.start_http(name, 100, [port: port], [env: [dispatch: dispatch]])
    end
  end

end
