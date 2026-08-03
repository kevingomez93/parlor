defmodule Parlor.YDoc.UpdateRecord do
  @moduledoc false

  use Ecto.Schema

  schema "yjs_updates" do
    field(:room_id, :string)
    field(:value, :binary)
    field(:version, :string)

    timestamps(type: :utc_datetime)
  end
end
