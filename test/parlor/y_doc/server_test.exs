defmodule Parlor.YDoc.ServerTest do
  use Parlor.DataCase, async: false

  alias Parlor.YDoc
  alias Parlor.YDoc.Server
  alias Parlor.YDoc.Store
  alias Parlor.Rooms

  setup do
    room_id = "yjs-server-#{System.unique_integer([:positive])}"
    topic = Rooms.topic(room_id)
    pid = start_supervised!({Server, room_id: room_id, topic: topic})

    %{room_id: room_id, topic: topic, pid: pid}
  end

  test "applies updates and persists document state", %{room_id: room_id, pid: pid} do
    doc = Yex.Doc.new()
    text = Yex.Doc.get_text(doc, "content")

    Yex.Doc.transaction(doc, fn ->
      Yex.Text.insert(text, 0, "hello")
    end)

    update = Yex.encode_state_as_update!(doc)
    {:ok, message} = Yex.Sync.message_encode({:sync, {:sync_update, update}})

    assert :ok = Server.process_message_v1(pid, message, self())

    assert Store.persisted?(room_id)
    loaded = Store.get_y_doc(room_id)
    loaded_text = Yex.Doc.get_text(loaded, "content")
    assert Yex.Text.to_string(loaded_text) == "hello"
  end

  test "rehydrates persisted state when server restarts", %{room_id: room_id, pid: pid} do
    doc = Yex.Doc.new()
    text = Yex.Doc.get_text(doc, "content")

    Yex.Doc.transaction(doc, fn ->
      Yex.Text.insert(text, 0, "persisted")
    end)

    update = Yex.encode_state_as_update!(doc)
    {:ok, message} = Yex.Sync.message_encode({:sync, {:sync_update, update}})
    assert :ok = Server.process_message_v1(pid, message, self())

    ref = Process.monitor(pid)
    assert :ok = GenServer.stop(pid, :normal)
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

    {:ok, new_pid} = YDoc.ensure(room_id)
    assert Process.alive?(new_pid)

    client_doc = Yex.Doc.new()
    {:ok, diff} = Store.get_diff(room_id, Yex.encode_state_vector!(client_doc))
    Yex.apply_update(client_doc, diff)

    client_text = Yex.Doc.get_text(client_doc, "content")
    assert Yex.Text.to_string(client_text) == "persisted"
  end

  test "registers in Horde and deduplicates ensure" do
    room_id = "yjs-horde-#{System.unique_integer([:positive])}"
    assert {:ok, pid} = YDoc.ensure(room_id)
    assert [{^pid, _}] = Horde.Registry.lookup(Parlor.YDocRegistry, room_id)
    assert {:ok, ^pid} = YDoc.ensure(room_id)
  end
end
