defmodule Parlor.YDoc.Store do
  @moduledoc """
  Persists Yjs document updates to Postgres with periodic snapshot flushing.
  """

  import Ecto.Query, only: [from: 2]

  alias Parlor.Repo
  alias Parlor.YDoc.UpdateRecord

  @v1 "v1"
  @v1_sv "v1_sv"

  @doc """
  Loads a Y.Doc by replaying persisted updates for a room.
  """
  @spec get_y_doc(String.t()) :: Yex.Doc.t()
  def get_y_doc(room_id) when is_binary(room_id) do
    doc = Yex.Doc.new()

    updates = list_updates(room_id)

    Yex.Doc.transaction(doc, fn ->
      Enum.each(updates, fn %{value: value} ->
        Yex.apply_update(doc, value)
      end)
    end)

    if length(updates) > flush_size() do
      flush_document(room_id, doc, updates)
    end

    doc
  end

  @doc """
  Inserts a new v1 update for a room.
  """
  @spec insert_update(String.t(), binary()) :: {:ok, UpdateRecord.t()} | {:error, term()}
  def insert_update(room_id, value) when is_binary(room_id) and is_binary(value) do
    now = DateTime.utc_now(:second)

    %UpdateRecord{room_id: room_id, value: value, version: @v1, inserted_at: now, updated_at: now}
    |> Repo.insert()
  end

  @doc """
  Returns the encoded diff for a room relative to a client state vector.
  """
  @spec get_diff(String.t(), binary()) :: {:ok, binary()} | {:error, term()}
  def get_diff(room_id, state_vector) when is_binary(room_id) and is_binary(state_vector) do
    doc = get_y_doc(room_id)
    Yex.encode_state_as_update(doc, state_vector)
  end

  @doc """
  Returns whether a room has any persisted Yjs data.
  """
  @spec persisted?(String.t()) :: boolean()
  def persisted?(room_id) when is_binary(room_id) do
    Repo.exists?(from(u in UpdateRecord, where: u.room_id == ^room_id))
  end

  @doc """
  Deletes all persisted Yjs data for a room.
  """
  @spec delete(String.t()) :: {non_neg_integer(), nil}
  def delete(room_id) when is_binary(room_id) do
    Repo.delete_all(from(u in UpdateRecord, where: u.room_id == ^room_id))
  end

  defp list_updates(room_id) do
    Repo.all(
      from(u in UpdateRecord,
        where: u.room_id == ^room_id and u.version == ^@v1,
        order_by: [asc: u.inserted_at]
      )
    )
  end

  defp get_state_vector(room_id) do
    Repo.one(
      from(u in UpdateRecord,
        where: u.room_id == ^room_id and u.version == ^@v1_sv,
        limit: 1
      )
    )
  end

  defp put_state_vector(room_id, state_vector) do
    now = DateTime.utc_now(:second)

    case get_state_vector(room_id) do
      nil ->
        %UpdateRecord{
          room_id: room_id,
          value: state_vector,
          version: @v1_sv,
          inserted_at: now,
          updated_at: now
        }
        |> Repo.insert()

      record ->
        record
        |> Ecto.Changeset.change(%{value: state_vector, updated_at: now})
        |> Repo.update()
    end
  end

  defp flush_document(room_id, doc, updates) do
    with {:ok, snapshot} <- Yex.encode_state_as_update(doc),
         {:ok, state_vector} <- Yex.encode_state_vector(doc) do
      clock = List.last(updates).inserted_at
      now = DateTime.utc_now(:second)

      %UpdateRecord{
        room_id: room_id,
        value: snapshot,
        version: @v1,
        inserted_at: now,
        updated_at: now
      }
      |> Repo.insert()

      put_state_vector(room_id, state_vector)
      clear_updates_before(room_id, clock)
    end

    doc
  end

  defp clear_updates_before(room_id, clock) do
    Repo.delete_all(
      from(u in UpdateRecord,
        where: u.room_id == ^room_id and u.inserted_at < ^clock and u.version == ^@v1
      )
    )
  end

  defp flush_size do
    Application.get_env(:parlor, :yjs_flush_size, 400)
  end
end
