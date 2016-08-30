defmodule Komoku.Storage.Repo.Migrations.CreateDataString do
  use Ecto.Migration

  def change do
    create table(:data_string) do
      add :key_id, references(:keys)
      add :value, :string
      add :time, :datetime, null: false
    end

    create index(:data_string, [:key_id])
    create index(:data_string, [:time])

  end
end
