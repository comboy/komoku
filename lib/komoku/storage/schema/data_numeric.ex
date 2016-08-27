defmodule Komoku.Storage.Schema.DataNumeric do
  use Ecto.Schema
  import Ecto.Changeset

  schema "data_numeric" do
    field :value, :float
    belongs_to :key, Komoku.Storage.Schema.Key
    timestamps(updated_at: false)
    # PONDER inserted_at? 
  end

  def changeset(key, params \\ %{}) do
    key
    |> cast(params, [:value, :inserted_at, :key_id])
    |> validate_required([:value, :key_id])
  end

end
