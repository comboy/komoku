defmodule Komoku.Storage.Schema.Key do
  use Ecto.Schema
  import Ecto.Changeset

  schema "keys" do
    field :name, :string
    field :key_type, :string
  end

  def changeset(key, params \\ %{}) do
    key
    |> cast(params, [:name, :key_type])
    |> validate_required([:name, :key_type])
    |> unique_constraint(:key_type)
    # TODO validate key_type within accepted key types
    # TODO check if key name is correct
    # TODO? rename key_type to type
  end

end
