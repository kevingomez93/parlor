defmodule ParlorWeb.YjsSyncTest do
  use ParlorWeb.ChannelCase, async: false

  alias Parlor.YDoc.Store

  test "syncs yjs document updates between clients" do
    room_id = "yjs-sync-#{System.unique_integer([:positive])}"

    {:ok, socket_a} =
      connect(ParlorWeb.RoomSocket, %{"token" => build_token(%{"sub" => "alice"})})

    {:ok, _, socket_a} = subscribe_and_join(socket_a, "room:#{room_id}", %{})
    assert_push "state:sync", %{state: %{}}

    {:ok, socket_b} =
      connect(ParlorWeb.RoomSocket, %{"token" => build_token(%{"sub" => "bob"})})

    {:ok, _, _socket_b} = subscribe_and_join(socket_b, "room:#{room_id}", %{})
    assert_push "state:sync", %{state: %{}}

    doc = Yex.Doc.new()
    text = Yex.Doc.get_text(doc, "content")

    Yex.Doc.transaction(doc, fn ->
      Yex.Text.insert(text, 0, "hello")
    end)

    update = Yex.encode_state_as_update!(doc)
    {:ok, message} = Yex.Sync.message_encode({:sync, {:sync_update, update}})

    ref = push(socket_a, "yjs", {:binary, message})
    assert_reply ref, :ok, %{}

    assert_push "yjs", {:binary, pushed_update}
    assert is_binary(pushed_update)

    loaded = Store.get_y_doc(room_id)
    loaded_text = Yex.Doc.get_text(loaded, "content")
    assert Yex.Text.to_string(loaded_text) == "hello"
  end

  test "responds to sync step 1 with sync step 2" do
    room_id = "yjs-step1-#{System.unique_integer([:positive])}"

    doc = Yex.Doc.new()
    text = Yex.Doc.get_text(doc, "content")

    Yex.Doc.transaction(doc, fn ->
      Yex.Text.insert(text, 0, "seed")
    end)

    {:ok, _} = Store.insert_update(room_id, Yex.encode_state_as_update!(doc))

    {:ok, socket} = connect(ParlorWeb.RoomSocket, %{"token" => build_token()})
    {:ok, _, socket} = subscribe_and_join(socket, "room:#{room_id}", %{})
    assert_push "state:sync", %{state: %{}}

    client_doc = Yex.Doc.new()
    sv = Yex.encode_state_vector!(client_doc)
    {:ok, sync_step1} = Yex.Sync.message_encode({:sync, {:sync_step1, sv}})

    ref = push(socket, "yjs", {:binary, sync_step1})
    assert_reply ref, :ok, %{}

    assert_push "yjs", {:binary, sync_step2}
    assert is_binary(sync_step2)
  end
end
