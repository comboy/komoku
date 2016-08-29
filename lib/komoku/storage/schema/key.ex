defmodule Komoku.Storage.Schema.Key do
  use Ecto.Schema
  import Ecto.Changeset

  alias Komoku.Storage.Schema.DataNumeric
  alias Komoku.Storage.Schema.DataBoolean

  schema "keys" do
    field :name, :string
    field :type, :string
    has_many :data_numeric, DataNumeric, on_delete: :delete_all
    has_many :data_boolean, DataBoolean, on_delete: :delete_all
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
