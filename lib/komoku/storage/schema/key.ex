defmodule Komoku.Storage.Schema.Key do
  use Ecto.Schema
  import Ecto.Changeset

  schema "keys" do
    field :name, :string
    field :type, :string
    # PONDER inserted_at? 
  end

  def changeset(key, params \\ %{}) do
    key
    |> cast(params, [:name, :type])
    |> validate_required([:name, :type])
    |> unique_constraint(:name)
    # TODO validate key_type within accepted key types
    # TODO check if key name is correct
  end

end
