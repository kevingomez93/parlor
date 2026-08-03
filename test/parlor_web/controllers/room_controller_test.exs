defmodule ParlorWeb.RoomControllerTest do
  use ParlorWeb.ConnCase, async: true

  @api_key "test-api-key"

  test "requires api key", %{conn: conn} do
    conn = get(conn, ~p"/api/rooms")
    assert json_response(conn, 401)["error"] == "unauthorized"
  end

  test "lists active rooms", %{conn: conn} do
    room_id = "api-list-#{System.unique_integer([:positive])}"
    assert {:ok, _pid} = Parlor.Rooms.ensure_room(room_id)

    conn =
      conn
      |> put_req_header("x-api-key", @api_key)
      |> get(~p"/api/rooms")

    data = json_response(conn, 200)["data"]
    assert Enum.any?(data, &(&1["id"] == room_id))
  end

  test "shows room info", %{conn: conn} do
    room_id = "api-show-#{System.unique_integer([:positive])}"
    assert {:ok, _pid} = Parlor.Rooms.ensure_room(room_id)
    {:ok, _} = Parlor.Room.set(room_id, "status", "ready")

    conn =
      conn
      |> put_req_header("x-api-key", @api_key)
      |> get(~p"/api/rooms/#{room_id}")

    data = json_response(conn, 200)["data"]
    assert data["id"] == room_id
    assert data["state"] == %{"status" => "ready"}
    assert is_map(data["presence"])
  end

  test "returns 404 for missing room", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-api-key", @api_key)
      |> get(~p"/api/rooms/missing-room")

    assert json_response(conn, 404)["error"] == "Room not found"
  end

  test "broadcasts events to room subscribers", %{conn: conn} do
    room_id = "api-broadcast-#{System.unique_integer([:positive])}"
    assert {:ok, _pid} = Parlor.Rooms.ensure_room(room_id)

    conn =
      conn
      |> put_req_header("x-api-key", @api_key)
      |> post(~p"/api/rooms/#{room_id}/broadcast", %{
        "event" => "server:event",
        "payload" => %{"message" => "hello"}
      })

    assert json_response(conn, 200)["status"] == "ok"
  end
end
