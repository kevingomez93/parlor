defmodule ParlorWeb.HealthController do
  use ParlorWeb, :controller

  def index(conn, _params) do
    json(conn, %{status: "ok", service: "parlor"})
  end
end
