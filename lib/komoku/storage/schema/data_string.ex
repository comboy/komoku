defmodule Komoku.Storage.Schema.DataString do
  use Ecto.Schema
  import Ecto.Changeset

  schema "data_string" do
    # TODO ponder about string length, do we want it to be a TEXT column in postgres?
    # AFAIK Ecto limits string type to 255 characters, so if we limit we need some reasonable error msgs
    field :value, :string
    field :time, Ecto.DateTime
    belongs_to :key, Komoku.Storage.Schema.Key
  end

  def changeset(key, params \\ %{}) do
    key
    |> cast(params, [:value, :time, :key_id])
    |> validate_required([:time, :key_id, :value])
  end

end
