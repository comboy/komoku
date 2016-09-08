defmodule Komoku.StatsTest do
  use ExUnit.Case

  alias Komoku.Server
  alias Komoku.Stats

  test "increment {group_key, key}" do
    Stats.increment(:foo, :bar)
    assert Stats.get(:foo) == %{:bar => 1}
    Stats.increment(:foo, :bar)
    assert Stats.get(:foo) == %{:bar => 2}
    Stats.increment(:foo, :baz)
    assert Stats.get(:foo) == %{:bar => 2, :baz => 1}
  end

  test "decrement {group_key, key}" do
    Stats.increment(:moo, :bar)
    assert Stats.get(:moo) == %{:bar => 1}
    Stats.decrement(:moo, :bar)
    assert Stats.get(:moo) == %{:bar => 0}
    Stats.decrement(:moo, :baz)
    assert Stats.get(:moo) == %{:bar => 0, :baz => -1}
  end

  test "server ops" do
    Server.insert_key "sops", "uptime"
    Server.update_key "sops", "uptime", %{"max_time" => 1}
    Server.delete_key "sops"
    Server.put "sops2", 123
    Server.get "sops2"
    Server.last "sops2"
    Server.list_keys
    %{delete_key: c_delete_key, insert_key: c_insert_key, last: c_last, put: c_put, get: c_get, update_key: c_update_key, list_keys: c_list_keys} = Stats.get(:server_op_count)

    Server.insert_key "sops3", "uptime"
    assert c_insert_key + 1 == Stats.get(:server_op_count, :insert_key)

    Server.update_key "sops3", "uptime", %{"max_time" => 4}
    assert c_update_key + 1 == Stats.get(:server_op_count, :update_key)

    Server.delete_key "sops3"
    assert c_delete_key + 1 == Stats.get(:server_op_count, :delete_key)

    Server.put "sops4", 1
    assert c_put + 1 == Stats.get(:server_op_count, :put)

    Server.get "sops4"
    assert c_get + 1 == Stats.get(:server_op_count, :get)

    Server.last "sops4"
    assert c_last + 1 == Stats.get(:server_op_count, :last)

    Server.list_keys
    assert c_list_keys + 1 == Stats.get(:server_op_count, :list_keys)
  end

  # TODO websocket clients count
end

