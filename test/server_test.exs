defmodule Komoku.ServerTest do
  # pretty hardcore since one test is killking the key master, but oh well it seems to work
  # may stop working when we start doing dp storage async in KH
  use ExUnit.Case, async: true

  alias Komoku.Server

  setup do
    # Explicitly get a connection before each test
    #:ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    #    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    :ok
  end

  # Keys operations

  test "create a key" do
    assert has_key?("boo") == false
    :ok = Server.insert_key "boo", "numeric"
    assert has_key?("boo") == true
  end

  test "delete a key" do
    :ok = Server.put("delete_key", 123)
    :ok = Server.delete_key("delete_key")
    assert Server.get("delete_key") == nil
    :ok = Server.put("delete_key", "true")
    assert Server.get("delete_key") == true
  end

  test "update a key when doesn't exist" do
    :ok = Server.update_key "boo_update", "numeric"
    assert has_key?("boo_update", "numeric") == true
  end

  test "update opts for an existing key" do
    name = "update_uptime_opts"
    :ok = Server.insert_key(name, "uptime", %{"max_time" => 60})
    assert has_key?(name, "uptime") == true
    assert Server.list_keys[name].opts["max_time"] == 60
    :ok = Server.update_key(name, "uptime", %{"max_time" => 77})
    assert has_key?(name, "uptime") == true
    assert Server.list_keys[name].opts["max_time"] == 77
  end

  test "try updating key with wrong type" do
    name = "update_wrong_type"
    :ok = Server.insert_key(name, "numeric")
    {:error, :type_mismatch} = Server.update_key(name, "boolean")
  end

  # Storing values

  test "store a value" do
    :ok = Server.insert_key "num", "numeric"
    :ok = Server.put("num", 123)
    assert Server.get("num") == 123
  end

  test "store a value with time" do
    ts = 1473000000
    :ok = Server.put("num_with_time", 123, ts)
    {123, ^ts} = Server.last("num_with_time")
  end

  test "get the last value" do
    :ok = Server.insert_key "num2", "numeric"
    assert Server.get("num2") == nil
    :ok = Server.put("num2", 123)
    assert Server.get("num2") == 123
    :ok = Server.put("num2", 345)
    assert Server.get("num2") == 345
  end

  test "get the last value with time" do
    :ok = Server.put("last_with_time", 123)
    time_now = :os.system_time(:milli_seconds) / 1_000
    {value, time} = Server.last("last_with_time")
    assert value == 123
    assert time > time_now - 0.1
    assert time < time_now + 0.1
  end

  test "guess numeric value type" do
    :ok = Server.put("guess_num", 123)
    assert Server.get("guess_num") == 123
    :ok = Server.put("guess_num2", 3.14)
    assert Server.get("guess_num2") == 3.14
  end

  test "guess boolean value type" do
    :ok = Server.put("guess_bool", false)
    assert Server.get("guess_bool") == false
    :ok = Server.put("guess_bool2", "true")
    assert Server.get("guess_bool2") == true
  end

  test "guess string value type" do
    :ok = Server.put("guess_string", "foo")
    assert Server.get("guess_string") == "foo"
  end

  test "try to insert invalid key type" do
    {:error, _} = Server.insert_key("invalid_type", "foo")
  end

  # Opts

  test "store key opts" do
    :ok = Server.insert_key("keyopts", "numeric", %{"foo" => 123})
    %{opts: %{"foo" => 123}} = Server.list_keys["keyopts"]
  end

  test "append default opts" do
    :ok = Server.insert_key("keyopts_uptime", "uptime")
    %{opts: %{"max_time" => 60}} = Server.list_keys["keyopts_uptime"]
  end

  # Time

  test "should store provided time properly" do
    ts = 1472600000
    :ok = Server.put("store_time", 123, ts)
    {123, time} = Server.last("store_time")
    assert time == ts
  end

  test "last value should be ordered by time not storage time" do
    ts1 = 14726_00000
    :ok = Server.put("store_time2", 123, ts1)
    ts2 = 14720_00000
    :ok = Server.put("store_time2", 123, ts2)
    {123, time} = Server.last("store_time2")
    assert time == ts1
  end

  # Boolean

  test "store a bool value" do
    :ok = Server.insert_key "bput", "boolean"
    :ok = Server.put("bput", false)
    assert Server.get("bput") == false
    :ok = Server.put("bput", true)
    assert Server.get("bput") == true
  end

  # String

  test "store a string value" do
    :ok = Server.insert_key "str_put", "string"
    :ok = Server.put("str_put", "boo!")
    assert Server.get("str_put") == "boo!"
  end

  # Subscription (most tsets in SubscriptionManager)

  test "subscribe to non-existent key" do
    :ok = Server.subscribe("sub_nonkey")
    :ok = Server.put("sub_nonkey", 123)
    assert_receive {:key_update, %{key: "sub_nonkey", time: _time, value: 123}}
  end

  # Uptime

  test "uptime key changes to false" do
    :ok = Server.insert_key("uptime_change", "uptime", %{"max_time" => 0.1})
    :ok = Server.put("uptime_change", true)
    assert Server.get("uptime_change") == true
    100 |> :timer.sleep
    assert Server.get("uptime_change") == false
  end

  test "uptime bump stops it from changing to false" do
    :ok = Server.insert_key("uptime_change2", "uptime", %{"max_time" => 0.1})
    :ok = Server.put("uptime_change2", true)
    assert Server.get("uptime_change2") == true
    50 |> :timer.sleep
    :ok = Server.put("uptime_change2", true)
    50 |> :timer.sleep
    assert Server.get("uptime_change2") == true
    50 |> :timer.sleep
    assert Server.get("uptime_change2") == false
  end

  test "uptime handled proprly on init" do
    :ok = Server.insert_key("uptime_change3", "uptime", %{"max_time" => 0.1})
    :ok = Server.put("uptime_change3", true)
    Process.exit(Komoku.KeyMaster |> Process.whereis, :kill) # KILL THE MASTER ! Which will also key key handlers
    100 |> :timer.sleep
    assert Server.get("uptime_change3") == false
  end

  test "uptime opts are getting properly updated" do
    key = "uptime_change4"
    :ok = Server.insert_key(key, "uptime", %{"max_time" => 0.1})
    :ok = Server.put(key, true)
    assert Server.get(key) == true
    100 |> :timer.sleep
    assert Server.get(key) == false
    :ok = Server.update_key(key, "uptime", %{"max_time" => 0.2})
    :ok = Server.put(key, true)
    assert Server.get(key) == true
    100 |> :timer.sleep
    assert Server.get(key) == true
    100 |> :timer.sleep
    assert Server.get(key) == false
  end

  # Counter

  test "counter simple put" do
    key = "counter1"
    :ok = Server.insert_key(key, "counter")
    :ok = Server.put(key, 123)
    assert Server.get(key) == 123
  end

  test "counter" do
    key = "counter2"
    :ok = Server.insert_key(key, "counter")
    :ok = Server.increment(key)
    assert Server.get(key) == 1
    :ok = Server.increment(key)
    :ok = Server.increment(key)
    assert Server.get(key) == 3
    :ok = Server.decrement(key)
    assert Server.get(key) == 2
  end

  test "counter by step" do
    key = "counter3"
    :ok = Server.insert_key(key, "counter")
    :ok = Server.increment(key, 3.6)
    assert Server.get(key) == 3.6
    :ok = Server.increment(key, 1.1)
    assert Server.get(key) == 4.7
    :ok = Server.decrement(key, 1)
    assert Server.get(key) == 3.7
  end

  # Fetch

  test "fetch last N values" do
    key = "fetch1"
    :ok = Server.insert_key(key, "numeric", %{same_value_resolution: 0, min_resolution: 0})
    ts = :os.system_time(:micro_seconds) / 1_000_000
    :ok = Server.put(key, 1)
    :ok = Server.put(key, 2)
    :ok = Server.put(key, 3)
    :ok = Server.put(key, 4)
    [{t4, v4}, {t3, v3}, {t2, v2}] = Server.fetch(key, %{"last" => 3})
    assert v4 == 4
    assert v3 == 3
    assert v2 == 2
    [t4, t3, t2] |> Enum.each(fn t -> assert_in_delta(t, ts, 0.1) end)
  end

  test "fetch nonexisting key" do
    assert Server.fetch("nosuchkey", %{"last" => 10}) == []
  end

  # TODO incr and decr with time param

  # Error handling

  test "incorrect key type" do
    assert Server.insert_key("invalid_type1", "foobar") == {:error, :invalid_type}
  end

  test "incorrect value type" do
    key = "incorrect_value_bool"
    :ok = Server.insert_key(key, "boolean")
    {:error, :invalid_value} = Server.put(key, 123)
    {:error, :invalid_value} = Server.put(key, "moo")
    :ok = Server.put(key, "true")
    :ok = Server.put(key, "false")
    :ok = Server.put(key, true)

    key = "incorrect_value_numeric"
    :ok = Server.insert_key(key, "numeric")
    {:error, :invalid_value} = Server.put(key, "mooo")
    {:error, :invalid_value} = Server.put(key, true)
    :ok = Server.put(key, "123")
    :ok = Server.put(key, "-32.123")
    :ok = Server.put(key, 123)
  end
  # TODO test for same_value_resultion and min_resolution, we need to have access to number of stored data points for that

  defp has_key?(name) do
    Server.list_keys |> Enum.any?(fn {k, _v} -> k == name end) == true
  end

  defp has_key?(name, type) do
    Server.list_keys |> Enum.any?(fn {k, %{type: type_}} -> k == name && type_ == type end) == true
  end
end
