defmodule ParlorWeb.PageController do
  use ParlorWeb, :controller

  def index(conn, _params) do
    json(conn, %{
      service: "parlor",
      version: Application.spec(:parlor, :vsn) |> to_string(),
      websocket: "/socket/websocket",
      api: %{
        health: "/api/health",
        rooms: "/api/rooms",
        room: "/api/rooms/:id",
        broadcast: "POST /api/rooms/:id/broadcast"
      },
      docs: "https://github.com/kevingomez93/parlor"
    })
  end
end
