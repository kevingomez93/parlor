defmodule ParlorWeb.AdminLiveTest do
  use ParlorWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @admin_auth "Basic " <> Base.encode64("admin:admin")

  test "requires basic auth", %{conn: conn} do
    conn = get(conn, ~p"/admin")
    assert conn.status == 401
  end

  test "renders room list with auth", %{conn: conn} do
    room_id = "admin-live-#{System.unique_integer([:positive])}"
    assert {:ok, _pid} = Parlor.Rooms.ensure_room(room_id)

    {:ok, _view, html} =
      conn
      |> put_req_header("authorization", @admin_auth)
      |> live(~p"/admin")

    assert html =~ room_id
    assert html =~ "Parlor Admin"
  end

  test "shows room detail page", %{conn: conn} do
    room_id = "admin-detail-#{System.unique_integer([:positive])}"
    assert {:ok, _pid} = Parlor.Rooms.ensure_room(room_id)
    {:ok, _} = Parlor.Room.set(room_id, "status", "ready")

    {:ok, view, html} =
      conn
      |> put_req_header("authorization", @admin_auth)
      |> live(~p"/admin/rooms/#{room_id}")

    assert html =~ room_id
    assert html =~ "ready"

    assert render(view) =~ "Shared state"
  end
end
