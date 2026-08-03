defmodule Parlor.RoomTest do
  use ExUnit.Case, async: false

  alias Parlor.Room
  alias Parlor.Rooms

  test "stores and retrieves shared state" do
    room_id = "room-#{System.unique_integer([:positive])}"
    assert {:ok, _pid} = Rooms.ensure_room(room_id)

    assert {:ok, state} = Room.set(room_id, "status", "ready")
    assert state["status"] == "ready"
    assert Room.get_state(room_id) == %{"status" => "ready"}

    assert {:ok, "ready", state} = Room.delete(room_id, "status")
    assert state == %{}
  end

  test "tracks member count" do
    room_id = "room-#{System.unique_integer([:positive])}"
    assert {:ok, pid} = Rooms.ensure_room(room_id)

    :ok = Room.member_joined(room_id)
    :ok = Room.member_joined(room_id)
    assert %{member_count: 2} = GenServer.call(pid, :info)

    :ok = Room.member_left(room_id)
    assert %{member_count: 1} = GenServer.call(pid, :info)
  end

  test "shuts down after idle ttl when empty" do
    room_id = "idle-#{System.unique_integer([:positive])}"
    assert {:ok, pid} = Rooms.ensure_room(room_id)
    ref = Process.monitor(pid)

    :ok = Room.member_joined(room_id)
    :ok = Room.member_left(room_id)

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 500
  end
end
