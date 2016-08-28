defmodule Komoku.Storage.Schema.DataNumeric do
  use Ecto.Schema
  import Ecto.Changeset

  schema "data_numeric" do
    field :value, :float
    field :time, Ecto.DateTime
    belongs_to :key, Komoku.Storage.Schema.Key
  end

  def changeset(key, params \\ %{}) do
    key
    |> cast(params, [:value, :time, :key_id])
    |> validate_required([:time, :key_id])
  end

end
