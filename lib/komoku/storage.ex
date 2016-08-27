defmodule Komoku.Storage do
  alias Komoku.Storage.Repo
  alias Komoku.Storage.Schema.Key

  def insert_key(name, key_type) do
    changeset = Key.changeset(%Key{}, %{name: name |> to_string, key_type: key_type})
    Repo.insert(changeset)
  end

  def list_keys do
    Key 
    |> Repo.all
    |> Enum.map(fn %Key{key_type: key_type, name: name} ->
      {name, %{type: key_type}}
    end)
    |> Enum.into(%{})
  end

end
