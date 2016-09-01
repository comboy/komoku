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

    #def handle_query(%{"define" => defs}) do
      ## PONDER not sure it's worth doing the status, we need to handle exceptions anyway somehew
      #{status, valid_defs} = defs |> Enum.reduce(:ok, fn({key, params}, status) ->
        #case params do
          #%{"type" => key_type} ->
          #_
            #{:invalid, nil}
        #end
      #end)

    #end

    def handle_query(_), do: :invalid_query

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
