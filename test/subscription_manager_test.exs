defmodule Komoku.SubscriptionManagerTest do
  use ExUnit.Case

  alias Komoku.SubscriptionManager, as: SM

  test "receive notification" do
    SM.subscribe("foo")
    SM.publish(%{key: "foo", time: Komoku.Util.ts, value: 32})
    assert_receive {:key_update, %{key: "foo", time: _time, value: 32}}
  end

  test "unsubscribe" do
    SM.subscribe("foo")
    SM.publish(%{key: "foo", time: Komoku.Util.ts, value: 32})
    assert_receive {:key_update, %{key: "foo", time: _time, value: 32}}
    SM.unsubscribe("foo")
    SM.publish(%{key: "foo", time: Komoku.Util.ts, value: 32})
    refute_receive {:key_update, %{key: "foo", time: _time, value: 32}}
  end

  test "unsubscribe all [pid]" do
    SM.subscribe("foo")
    SM.subscribe("bar")
    SM.unsubscribe_all(self)
    SM.publish(%{key: "foo", time: Komoku.Util.ts, value: 32})
    SM.publish(%{key: "bar", time: Komoku.Util.ts, value: 32})
    refute_receive {:key_update, %{key: "foo"}}
    refute_receive {:key_update, %{key: "bar"}}
  end

  test "unsubscribe all name" do
    SM.subscribe("foo")
    SM.unsubscribe_all("foo")
    SM.publish(%{key: "foo", time: Komoku.Util.ts, value: 32})
    refute_receive {:key_update, %{key: "foo"}}
  end

  test "cleanup" do
    # hard to test if it actually cleanups dead processes from its state, check if doesn't raise and keeps those alive
    SM.subscribe("foo")
    send(SM, :cleanup)
    SM.publish(%{key: "foo", time: Komoku.Util.ts, value: 32})
    assert_receive {:key_update, %{key: "foo", time: _time, value: 32}}
  end

  test "stats" do
    SM.subscribe("stats1")
    Task.start(fn ->
      SM.subscribe("stats1")
      100 |> :timer.sleep
    end)
    10 |> :timer.sleep # let the task subscribe
    assert SM.stats["stats1"] == 2
  end
end
