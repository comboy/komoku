defmodule Komoku.StorageTest do
  use ExUnit.Case#, async: true

  alias Komoku.Storage.Repo
  alias Komoku.Storage

  setup do
    Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)
    # Explicitly get a connection before each test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "create a key" do 
    Storage.insert_key "boo", "numeric"
    %{"boo" => %{type: "numeric"}} = Storage.list_keys
  end

end
