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
    # Apart from websocket we may go with different communication channels, e.g. http server
    Komoku.Server.Websocket.start_link
  end
end
