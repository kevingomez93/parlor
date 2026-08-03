defmodule Parlor.Rooms.Store do
  @moduledoc """
  Persists room shared state to Postgres.
  """

  import Ecto.Query, only: [from: 2]

  alias Parlor.Repo
  alias Parlor.Rooms.RoomRecord

  @doc """
  Loads persisted state for a room, or an empty map if none exists.
  """
  @spec load_state(String.t()) :: map()
  def load_state(room_id) when is_binary(room_id) do
    case Repo.get(RoomRecord, room_id) do
      nil -> %{}
      %RoomRecord{state: state} -> state || %{}
    end
  end

  @doc """
  Upserts shared state for a room.
  """
  @spec save_state(String.t(), map()) :: {:ok, RoomRecord.t()} | {:error, Ecto.Changeset.t()}
  def save_state(room_id, state) when is_binary(room_id) and is_map(state) do
    now = DateTime.utc_now(:second)

    %RoomRecord{id: room_id, state: state, inserted_at: now, updated_at: now}
    |> Repo.insert(
      on_conflict: [set: [state: state, updated_at: now]],
      conflict_target: :id
    )
  end

  @doc """
  Returns whether a room has a persisted record.
  """
  @spec persisted?(String.t()) :: boolean()
  def persisted?(room_id) when is_binary(room_id) do
    Repo.exists?(from(r in RoomRecord, where: r.id == ^room_id))
  end

  @doc """
  Deletes persisted state for a room.
  """
  @spec delete(String.t()) :: {:ok, RoomRecord.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def delete(room_id) when is_binary(room_id) do
    case Repo.get(RoomRecord, room_id) do
      nil -> {:error, :not_found}
      record -> Repo.delete(record)
    end
  end
end
