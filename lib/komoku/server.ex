defmodule Komoku.Server do
  # TODO 
  # Point of access to the values
  # Manages genservers for specific values, also starts engine (eg database workers pool)
  # Represents public API
  # * put, get etc
  #
  # Should it also start e.g. websocket server
  # It would be nice if it was not a genserver to avoid bottleneck

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
end
