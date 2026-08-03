defmodule Parlor.Rooms.RoomRecord do
  @moduledoc """
  Ecto schema for persisted room shared state.
  """

  use Ecto.Schema

  @primary_key {:id, :string, autogenerate: false}
  schema "rooms" do
    field(:state, :map, default: %{})

    timestamps(type: :utc_datetime)
  end
end
