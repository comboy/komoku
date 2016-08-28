defmodule Komoku.StorageTest do
  use ExUnit.Case, async: true

  alias Komoku.Storage

  setup do
    # Explicitly get a connection before each test
    #:ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    #    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    :ok
  end

  test "create a key" do 
    assert has_key?("boo") == false
    :ok = Storage.insert_key "boo", "numeric"
    assert has_key?("boo") == true
  end

  test "store a value" do
    :ok = Storage.insert_key "num", "numeric"
    :ok = Storage.put("num", 123)
    assert Storage.get("num") == 123
  end

  test "retrieve last value" do
    :ok = Storage.insert_key "num2", "numeric"
    assert Storage.get("num2") == nil
    :ok = Storage.put("num2", 123)
    assert Storage.get("num2") == 123
    :ok = Storage.put("num2", 345)
    assert Storage.get("num2") == 345
  end

  defp has_key?(name) do
    Storage.list_keys |> Enum.any?(fn {k, _v} -> k == name end) == true
  end
end
