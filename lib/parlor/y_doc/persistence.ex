defmodule Parlor.YDoc.Persistence do
  @moduledoc false

  @behaviour Yex.Sync.SharedDoc.PersistenceBehaviour

  alias Parlor.YDoc.Store

  @impl true
  def bind(_state, room_id, doc) do
    persisted_doc = Store.get_y_doc(room_id)

    {:ok, new_updates} = Yex.encode_state_as_update(doc)
    Store.insert_update(room_id, new_updates)

    Yex.apply_update(doc, Yex.encode_state_as_update!(persisted_doc))
    :ok
  end

  @impl true
  def unbind(_state, _room_id, _doc), do: :ok

  @impl true
  def update_v1(_state, update, room_id, _doc) do
    Store.insert_update(room_id, update)
    :ok
  end
end
