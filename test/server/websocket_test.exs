defmodule Komoku.Server.WebsocketTest do
  use ExUnit.Case
  alias Komoku.Storage

  setup do
    {:ok, socket} = Socket.Web.connect("127.0.0.1", 4545)
    {:ok, socket: socket}
  end

  # TODO we should be closing these connectios after each test, but I think on_exit doesn't have access to the context?

  test "get key value", c do
    :ok = Storage.put("ws1", 8)
    c[:socket] |> push(%{get: %{key: "ws1"}})
    assert recv(c[:socket]) == 8
  end

  test "put test value", c do
    c[:socket] |> push(%{put: %{key: "ws2", value: 7}})
    assert recv(c[:socket]) == "ack"
    c[:socket] |> push(%{get: %{key: "ws2"}})
    assert recv(c[:socket]) == 7
  end

  test "list keys", c do
    :ok = Storage.insert_key("ws_list", "numeric")
    c[:socket] |> push(%{keys: %{}})
    assert recv(c[:socket]) |> Enum.any?(fn {key, info} -> key == "ws_list" && info["type"] == "numeric" end)
  end

  test "subscribe to key change", c do
    :ok = Storage.insert_key("ws_key_sub", "numeric")
    c[:socket] |> push(%{sub: %{key: "ws_key_sub"}})
    assert recv(c[:socket]) == "ack"
    :ok = Storage.put("ws_key_sub", 123)
    %{"pub" => %{"key" => "ws_key_sub", "value" => 123}} = recv(c[:socket]) 
    :ok = Storage.put("ws_key_sub", 234)
    %{"pub" => %{"key" => "ws_key_sub", "value" => 234, "previous" => 123}} = recv(c[:socket]) 
  end


  defp push(socket, data) do
    socket |> Socket.Web.send!({:text, data |> Poison.encode!})
  end

  defp recv(socket) do
    {:text, reply} = socket |> Socket.Web.recv!
    reply |> Poison.decode!
  end
end
