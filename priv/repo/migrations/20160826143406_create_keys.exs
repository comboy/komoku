defmodule Komoku.Storage.Repo.Migrations.CreateKeys do
  use Ecto.Migration

  def change do
    create table(:keys) do
      add :name, :string
      add :key_type, :string
    end

    create unique_index(:keys, [:name])
  end
end
