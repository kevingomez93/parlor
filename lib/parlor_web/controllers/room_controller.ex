defmodule ParlorWeb.RoomController do
  use ParlorWeb, :controller

  alias Parlor.Rooms

  def index(conn, _params) do
    json(conn, %{data: Rooms.list()})
  end

  def show(conn, %{"id" => id}) do
    case Rooms.get_info(id) do
      {:ok, info} ->
        json(conn, %{data: info})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Room not found"})
    end
  end

  def broadcast(conn, %{"id" => id} = params) do
    event = Map.get(params, "event", "server:event")
    payload = Map.get(params, "payload", %{})

    if is_map(payload) do
      case Rooms.broadcast(id, event, payload) do
        :ok ->
          json(conn, %{status: "ok"})

        {:error, reason} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: inspect(reason)})
      end
    else
      conn
      |> put_status(:bad_request)
      |> json(%{error: "payload must be a JSON object"})
    end
  end
end
