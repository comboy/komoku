defmodule Komoku.Server.Websocket do

  require Logger

  def init(config) do
    start_link(config)
  end

  def start_link(config) do
    port = config[:port]
    name = config[:name] || "websocket_#{port}"

    dispatch = :cowboy_router.compile([
      { :_, # all hostnames
        [{"/", Komoku.Server.Websocket.Handler, [%{name: name}]}]
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
