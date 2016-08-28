defmodule Komoku.Storage.Repo.Migrations.CreateDataNumeric do
  use Ecto.Migration

  def change do
    create table(:data_numeric) do
      add :key_id, references(:keys)
      add :value, :float
      add :time, :datetime, null: false
    end

    create index(:data_numeric, [:key_id])
    create index(:data_numeric, [:time])
  end
end
