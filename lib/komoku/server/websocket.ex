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
      Logger.debug "< #{content}"
      #IO.puts "GOT msg #{content |> inspect}"
      #IO.puts "I AM #{self |> inspect}"
      #IO.puts "my state: #{state |> inspect}"
      {reply, state} = case Poison.decode(content) do
        {:ok, query} ->
          handle_query(query, state)
        {:error, _} ->
          {%{error: "invalid_json"}, state}
      end
      {:reply, {:text, reply |> Poison.encode!}, req, state}
    end

    def websocket_handle(data, _req, _state), do: IO.puts "oh we got #{data |> inspect}"

    # TODO what is this
    def websocket_info(info, req, state) do
      IO.puts "INFO: #{info |> inspect}"
      {:ok, req, state}
    end

    def handle_query(query, state) do
      # state modification will be needed when authentication is added
      reply = case query do
        %{"get" => key} ->
          Logger.debug "GET #{key}"
          Komoku.Storage.get(key)
         _ ->
           %{error: "invalid_query"}
      end
      {reply, state}
    end

  end

  def start_link do
    # TODO we need ssl, cert files should be an option in config.exis
    dispatch = :cowboy_router.compile([
      { :_, # all hostnames
        [{"/", Handler, []}]
      }
    ])

    # TODO:what is 100, keywords instead of tuples, check if there's a simpler dispatch
    :cowboy.start_http(:http, 100, [{:port, 4545}], [{:env, [{:dispatch, dispatch}]}])
  end


end
