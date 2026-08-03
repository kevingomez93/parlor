defmodule Parlor.Rooms.StoreTest do
  use Parlor.DataCase, async: true

  alias Parlor.Rooms.Store

  test "load_state returns empty map when room is not persisted" do
    assert Store.load_state("missing-room") == %{}
    refute Store.persisted?("missing-room")
  end

  test "save_state inserts and load_state reads back" do
    room_id = "store-#{System.unique_integer([:positive])}"

    assert {:ok, _record} = Store.save_state(room_id, %{"status" => "ready"})
    assert Store.persisted?(room_id)
    assert Store.load_state(room_id) == %{"status" => "ready"}
  end

  test "save_state upserts existing room state" do
    room_id = "store-upsert-#{System.unique_integer([:positive])}"

    assert {:ok, _} = Store.save_state(room_id, %{"count" => 1})
    assert {:ok, _} = Store.save_state(room_id, %{"count" => 2})

    assert Store.load_state(room_id) == %{"count" => 2}
  end

  test "delete removes persisted room state" do
    room_id = "store-delete-#{System.unique_integer([:positive])}"

    assert {:ok, _} = Store.save_state(room_id, %{"status" => "ready"})
    assert {:ok, _} = Store.delete(room_id)
    assert Store.load_state(room_id) == %{}
    assert {:error, :not_found} = Store.delete(room_id)
  end
end
