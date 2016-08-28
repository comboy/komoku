defmodule Komoku.Storage.Repo.Migrations.CreateDataBoolean do
  use Ecto.Migration

  def change do
    create table(:data_boolean) do
      add :key_id, references(:keys)
      add :value, :boolean
      add :time, :datetime, null: false
    end

    create index(:data_boolean, [:key_id])
    create index(:data_boolean, [:time])
  end
end
