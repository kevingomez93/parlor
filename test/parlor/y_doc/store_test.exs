defmodule Parlor.YDoc.StoreTest do
  use Parlor.DataCase, async: true

  alias Parlor.YDoc.Store

  test "persisted? is false for unknown room" do
    refute Store.persisted?("missing-room")
  end

  test "insert_update and get_y_doc round-trip document state" do
    room_id = "yjs-#{System.unique_integer([:positive])}"
    doc = Yex.Doc.new()
    text = Yex.Doc.get_text(doc, "content")

    Yex.Doc.transaction(doc, fn ->
      Yex.Text.insert(text, 0, "hello")
    end)

    update = Yex.encode_state_as_update!(doc)
    assert {:ok, _} = Store.insert_update(room_id, update)
    assert Store.persisted?(room_id)

    loaded = Store.get_y_doc(room_id)
    loaded_text = Yex.Doc.get_text(loaded, "content")
    assert Yex.Text.to_string(loaded_text) == "hello"
  end

  test "get_diff returns missing updates for a client state vector" do
    room_id = "yjs-diff-#{System.unique_integer([:positive])}"

    doc = Yex.Doc.new()
    text = Yex.Doc.get_text(doc, "content")

    Yex.Doc.transaction(doc, fn ->
      Yex.Text.insert(text, 0, "hello")
    end)

    {:ok, _} = Store.insert_update(room_id, Yex.encode_state_as_update!(doc))

    client_doc = Yex.Doc.new()
    {:ok, diff} = Store.get_diff(room_id, Yex.encode_state_vector!(client_doc))
    Yex.apply_update(client_doc, diff)

    client_text = Yex.Doc.get_text(client_doc, "content")
    assert Yex.Text.to_string(client_text) == "hello"
  end

  test "delete removes persisted updates" do
    room_id = "yjs-delete-#{System.unique_integer([:positive])}"
    doc = Yex.Doc.new()

    {:ok, _} = Store.insert_update(room_id, Yex.encode_state_as_update!(doc))
    assert Store.persisted?(room_id)

    {1, nil} = Store.delete(room_id)
    refute Store.persisted?(room_id)
  end
end
