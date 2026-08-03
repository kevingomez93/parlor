defmodule ParlorWeb.RoomChannelTest do
  use ParlorWeb.ChannelCase, async: false

  alias Parlor.Room
  alias Parlor.Rooms

  test "joins with a valid token and receives state sync", %{token: token} do
    {:ok, socket} = connect(ParlorWeb.RoomSocket, %{"token" => token})
    room_id = "lobby-#{System.unique_integer([:positive])}"

    assert {:ok, _, socket} = subscribe_and_join(socket, "room:#{room_id}", %{})

    assert_push "state:sync", %{state: %{}}
    assert socket.assigns.room_id == room_id
  end

  test "rejects join for unauthorized room" do
    restricted_token = build_token(%{"rooms" => ["other-room"]})
    {:ok, socket} = connect(ParlorWeb.RoomSocket, %{"token" => restricted_token})
    room_id = "secret-#{System.unique_integer([:positive])}"

    assert {:error, %{reason: "unauthorized"}} =
             subscribe_and_join(socket, "room:#{room_id}", %{})
  end

  test "broadcasts messages between clients" do
    room_id = "chat-#{System.unique_integer([:positive])}"

    {:ok, socket_a} =
      connect(ParlorWeb.RoomSocket, %{"token" => build_token(%{"sub" => "alice"})})

    {:ok, _, socket_a} = subscribe_and_join(socket_a, "room:#{room_id}", %{})
    assert_push "state:sync", %{state: %{}}

    {:ok, socket_b} =
      connect(ParlorWeb.RoomSocket, %{"token" => build_token(%{"sub" => "bob"})})

    {:ok, _, _socket_b} = subscribe_and_join(socket_b, "room:#{room_id}", %{})
    assert_push "state:sync", %{state: %{}}

    ref = push(socket_a, "msg", %{"text" => "hello"})
    assert_reply ref, :ok, %{}

    assert_push "msg", %{"text" => "hello", "from" => "alice"}
    refute_push "msg", %{"text" => "hello", "from" => "alice"}
  end

  test "syncs shared state changes" do
    room_id = "state-#{System.unique_integer([:positive])}"

    {:ok, socket_a} =
      connect(ParlorWeb.RoomSocket, %{"token" => build_token(%{"sub" => "alice"})})

    {:ok, _, socket_a} = subscribe_and_join(socket_a, "room:#{room_id}", %{})
    assert_push "state:sync", %{state: %{}}

    {:ok, socket_b} =
      connect(ParlorWeb.RoomSocket, %{"token" => build_token(%{"sub" => "bob"})})

    {:ok, _, _socket_b} = subscribe_and_join(socket_b, "room:#{room_id}", %{})
    assert_push "state:sync", %{state: %{}}

    ref = push(socket_a, "state:set", %{"key" => "status", "value" => "ready"})
    assert_reply ref, :ok, %{}

    assert_push "state:patch", %{
      "op" => "set",
      "key" => "status",
      "value" => "ready",
      "state" => %{"status" => "ready"}
    }

    assert Room.get_state(room_id) == %{"status" => "ready"}
  end

  test "receives server broadcast events via pubsub" do
    room_id = "server-#{System.unique_integer([:positive])}"

    {:ok, socket} = connect(ParlorWeb.RoomSocket, %{"token" => build_token()})
    {:ok, _, _socket} = subscribe_and_join(socket, "room:#{room_id}", %{})
    assert_push "state:sync", %{state: %{}}

    :ok = Rooms.broadcast(room_id, "server:event", %{"message" => "from backend"})
    assert_push "server:event", %{"message" => "from backend"}
  end
end
