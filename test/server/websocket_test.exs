defmodule Komoku.Server.WebsocketTest do
  use ExUnit.Case
  alias Komoku.Storage

  test "get key value" do
    :ok = Storage.insert_key "ws1", "numeric"
    :ok = Storage.put("ws1", 8)
    {:ok, socket} = Socket.Web.connect "127.0.0.1", 4545
    socket |> Socket.Web.send!({:text, %{get: "ws1"} |> Poison.encode!})
    {:text, reply} = socket |> Socket.Web.recv!
    assert reply |> Poison.decode! == 8
  end
end
