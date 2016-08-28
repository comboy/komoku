defmodule Komoku.Server.WebsocketTest do
  use ExUnit.Case
  alias Komoku.Storage

  # TODO setup with socket connection

  test "get key value" do
    :ok = Storage.insert_key("ws1", "numeric")
    :ok = Storage.put("ws1", 8)
    {:ok, socket} = Socket.Web.connect("127.0.0.1", 4545)
    socket |> push(%{get: %{key: "ws1"}})
    assert recv(socket) == 8
  end

  test "put test value" do
    :ok = Storage.insert_key("ws2", "numeric")
    {:ok, socket} = Socket.Web.connect("127.0.0.1", 4545)
    socket |> push(%{put: %{key: "ws2", value: 7}})
    assert recv(socket) == "ack"
    socket |> push(%{get: %{key: "ws2"}})
    assert recv(socket) == 7
  end

  test "list keys" do
    :ok = Storage.insert_key("ws_list", "numeric")
    {:ok, socket} = Socket.Web.connect("127.0.0.1", 4545)
    socket |> push(%{keys: %{}})
    assert recv(socket) |> Enum.any?(fn {key, info} -> key == "ws_list" && info["type"] == "numeric" end)
  end

  defp push(socket, data) do
    socket |> Socket.Web.send!({:text, data |> Poison.encode!})
  end

  defp recv(socket) do
    {:text, reply} = socket |> Socket.Web.recv!
    reply |> Poison.decode!
  end
end
