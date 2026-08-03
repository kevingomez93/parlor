defmodule Parlor.Repo.Migrations.CreateRooms do
  use Ecto.Migration

  def change do
    create table(:rooms, primary_key: false) do
      add :id, :text, primary_key: true
      add :state, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end
  end
end
