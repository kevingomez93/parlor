defmodule Parlor.Repo.Migrations.CreateYjsUpdates do
  use Ecto.Migration

  def change do
    create table(:yjs_updates, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :room_id, :text, null: false
      add :version, :string, null: false
      add :value, :binary, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:yjs_updates, [:room_id, :version, :inserted_at])
  end
end
