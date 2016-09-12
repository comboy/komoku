defmodule Komoku.Server.WebsocketV2Test do
  use ExUnit.Case
  alias Komoku.Server

  setup do
    {:ok, socket} = Socket.Web.connect("127.0.0.1", 7274)
    {:ok, socket: socket}
  end

  # TODO we should be closing these connectios after each test, but I think on_exit doesn't have access to the context?

  test "get key value", c do
    :ok = Server.put("w2s1", 8)
    c[:socket] |> push(%{get: %{key: "w2s1"}})
    assert recv(c[:socket]) == %{"result" => 8}
  end

  test "put test value", c do
    c[:socket] |> push(%{put: %{key: "w2s2", value: 7}})
    assert recv(c[:socket]) == %{"result" => "ok"}
    c[:socket] |> push(%{get: %{key: "w2s2"}})
    assert recv(c[:socket]) == %{"result" => 7}
  end

  test "get last", c do
    ts = 1473007432
    :ok = Server.put("w2s1_last", 8, ts)
    c[:socket] |> push(%{last: %{key: "w2s1_last"}})
    assert recv(c[:socket]) == %{"result" => %{"value" => 8, "time" => ts}}
  end

  test "list keys", c do
    :ok = Server.insert_key("w2s_list", "numeric")
    c[:socket] |> push(%{keys: %{}})
    %{"result" => result} = recv(c[:socket]) 
    assert result |> Enum.any?(fn {key, info} -> key == "w2s_list" && info["type"] == "numeric" end)
  end

  test "define keys", c do
    c[:socket] |> push(%{define: %{deftest: %{type: "numeric"}}})
    assert recv(c[:socket]) == %{"result" => "ok"}
    assert Server.list_keys["deftest"].type == "numeric"

    c[:socket] |> push(%{define: %{deftest2: %{type: "uptime", opts: %{max_time: 7}}}})
    assert recv(c[:socket]) == %{"result" => "ok"}
    assert Server.list_keys["deftest2"].type == "uptime"
    assert Server.list_keys["deftest2"].opts["max_time"] == 7
  end

  test "subscribe to key change", c do
    :ok = Server.insert_key("w2s_key_sub", "numeric")
    c[:socket] |> push(%{sub: %{key: "w2s_key_sub"}})
    assert recv(c[:socket]) == %{"result" => "ok"}
    :ok = Server.put("w2s_key_sub", 123)
    %{"pub" => %{"key" => "w2s_key_sub", "value" => 123}} = recv(c[:socket]) 
    :ok = Server.put("w2s_key_sub", 234)
    %{"pub" => %{"key" => "w2s_key_sub", "value" => 234, "previous" => 123}} = recv(c[:socket]) 
  end

  test "subscribe to non-existent key", c do
    key = "w2s_key_sub_none"
    c[:socket] |> push(%{sub: %{key: key}})
    :ok = Server.insert_key(key, "numeric")
    assert recv(c[:socket]) == %{"result" => "ok"}
    :ok = Server.put(key, 123)
    %{"pub" => %{"key" => ^key, "value" => 123}} = recv(c[:socket]) 
    :ok = Server.put(key, 234)
    %{"pub" => %{"key" => ^key, "value" => 234, "previous" => 123}} = recv(c[:socket]) 
  end

  test "subscribe to key which gets deleted", c do
    key = "w2s_key_sub_none2"
    c[:socket] |> push(%{sub: %{key: key}})
    assert recv(c[:socket]) == %{"result" => "ok"}
    :ok = Server.insert_key(key, "numeric")
    :ok = Server.delete_key(key)
    :ok = Server.put(key, "foo")
    %{"pub" => %{"key" => ^key, "value" => "foo"}} = recv(c[:socket]) 
    :ok = Server.put(key, "bar")
    %{"pub" => %{"key" => ^key, "value" => "bar", "previous" => "foo"}} = recv(c[:socket]) 
  end

  test "unsubscribe from key change", c do
    :ok = Server.insert_key("w2s_key_sub2", "numeric")
    c[:socket] |> push(%{sub: %{key: "w2s_key_sub2"}})
    assert recv(c[:socket]) == %{"result" => "ok"}
    c[:socket] |> push(%{unsub: %{key: "w2s_key_sub2"}})
    :ok = Server.put("w2s_key_sub2", 123)
    c[:socket] |> push(%{put: %{key: "w2s_key_sub2", value: 1}})
    assert recv(c[:socket]) == %{"result" => "ok"} # if subscription was stil lon first received msg would be a notification
  end

  test "invalid query", c do
    c[:socket] |> push(%{some_invalid: "query"})
    assert recv(c[:socket]) == %{"error" => "invalid_query"}
  end

  test "using query_id", c do
    c[:socket] |> push(%{put: %{key: "w2s_qid", value: 7,}, query_id: "bzium"})
    assert recv(c[:socket]) == %{"result" => "ok", "query_id" => "bzium"}
  end

  defp push(socket, data) do
    socket |> Socket.Web.send!({:text, data |> Poison.encode!})
  end

  defp recv(socket) do
    {:text, reply} = socket |> Socket.Web.recv!
    reply |> Poison.decode!
  end
end
