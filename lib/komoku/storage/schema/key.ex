defmodule Komoku.Storage.Schema.Key do
  use Ecto.Schema
  import Ecto.Changeset

  alias Komoku.Storage.Schema.DataNumeric
  alias Komoku.Storage.Schema.DataBoolean

  schema "keys" do
    field :name, :string
    field :type, :string
    field :opts, :map # TODO {:map, KeyOpts type} but it's a bit tricky because allowed opts depend on the type
    has_many :data_numeric, DataNumeric, on_delete: :delete_all
    has_many :data_boolean, DataBoolean, on_delete: :delete_all
    has_many :data_string, DataBoolean, on_delete: :delete_all
    # PONDER inserted_at?
  end

  def changeset(key, params \\ %{}) do
    key
    |> cast(params, [:name, :type, :opts])
    |> validate_required([:name, :type, :opts])
    |> validate_key_type
    # TODO validate opts
    |> unique_constraint(:name)
    # TODO validate key_type within accepted key types
    # TODO check if key name is correct
  end

  defp validate_key_type(changeset) do
    type = changeset |> get_field(:type)
    # TODO move list to a common place
    unless ["numeric", "boolean", "string", "uptime", "counter"] |> Enum.member?(type) do
      changeset |> add_error(:type, "invalid key type")
    else
      changeset
    end
  end

end
