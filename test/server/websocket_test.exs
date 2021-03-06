defmodule Komoku.Server.WebsocketTest do
  use ExUnit.Case
  alias Komoku.Server

  setup do
    {:ok, socket} = Socket.Web.connect("127.0.0.1", 7272)
    {:ok, socket: socket}
  end

  # TODO we should be closing these connectios after each test, but I think on_exit doesn't have access to the context?

  test "get key value", c do
    :ok = Server.put("ws1", 8)
    c[:socket] |> push(%{get: %{key: "ws1"}})
    assert recv(c[:socket]) == 8
  end

  test "put test value", c do
    c[:socket] |> push(%{put: %{key: "ws2", value: 7}})
    assert recv(c[:socket]) == "ack"
    c[:socket] |> push(%{get: %{key: "ws2"}})
    assert recv(c[:socket]) == 7
  end

  test "get last", c do
    ts = 1473007432
    :ok = Server.put("ws1_last", 8, ts)
    c[:socket] |> push(%{last: %{key: "ws1_last"}})
    assert recv(c[:socket]) == %{"value" => 8, "time" => ts}
  end

  test "list keys", c do
    :ok = Server.insert_key("ws_list", "numeric")
    c[:socket] |> push(%{keys: %{}})
    assert recv(c[:socket]) |> Enum.any?(fn {key, info} -> key == "ws_list" && info["type"] == "numeric" end)
  end

  test "define keys", c do
    c[:socket] |> push(%{define: %{deftest: %{type: "numeric"}}})
    assert recv(c[:socket]) == "ack"
    assert Server.list_keys["deftest"].type == "numeric"

    c[:socket] |> push(%{define: %{deftest2: %{type: "uptime", opts: %{max_time: 7}}}})
    assert recv(c[:socket]) == "ack"
    assert Server.list_keys["deftest2"].type == "uptime"
    assert Server.list_keys["deftest2"].opts["max_time"] == 7
  end

  test "subscribe to key change", c do
    :ok = Server.insert_key("ws_key_sub", "numeric")
    c[:socket] |> push(%{sub: %{key: "ws_key_sub"}})
    assert recv(c[:socket]) == "ack"
    :ok = Server.put("ws_key_sub", 123)
    %{"pub" => %{"key" => "ws_key_sub", "value" => 123}} = recv(c[:socket]) 
    :ok = Server.put("ws_key_sub", 234)
    %{"pub" => %{"key" => "ws_key_sub", "value" => 234, "previous" => 123}} = recv(c[:socket]) 
  end

  test "unsubscribe from key change", c do
    :ok = Server.insert_key("ws_key_sub2", "numeric")
    c[:socket] |> push(%{sub: %{key: "ws_key_sub2"}})
    assert recv(c[:socket]) == "ack"
    c[:socket] |> push(%{unsub: %{key: "ws_key_sub2"}})
    :ok = Server.put("ws_key_sub2", 123)
    c[:socket] |> push(%{put: %{key: "ws_key_sub2", value: 1}})
    assert recv(c[:socket]) == "ack" # if subscription was stil lon first received msg would be a notification
  end

  test "ssl connection" do
    {:ok, socket} = Socket.Web.connect("127.0.0.1", 7273, secure: true)
    socket |> push(%{put: %{key: "wss1", value: 1}})
    assert recv(socket) == "ack"
    socket |> push(%{get: %{key: "wss1"}})
    assert recv(socket) == 1 
  end

  test "put incorrect value", c do
    c[:socket] |> push(%{put: %{key: "w2s2_incorrect", value: 7}})
    assert recv(c[:socket]) == "ack"
    c[:socket] |> push(%{put: %{key: "w2s2_incorrect", value: "foo"}})
    assert recv(c[:socket]) == %{"error" => "invalid_value"}
  end

  defp push(socket, data) do
    socket |> Socket.Web.send!({:text, data |> Poison.encode!})
  end

  defp recv(socket) do
    {:text, reply} = socket |> Socket.Web.recv!
    reply |> Poison.decode!
  end
end
