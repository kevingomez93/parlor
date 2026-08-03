defmodule ParlorWeb.Router do
  use ParlorWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug ParlorWeb.Plugs.ApiAuth
  end

  scope "/api", ParlorWeb do
    pipe_through :api

    get "/health", HealthController, :index
  end

  scope "/api", ParlorWeb do
    pipe_through [:api, :api_auth]

    get "/rooms", RoomController, :index
    get "/rooms/:id", RoomController, :show
    post "/rooms/:id/broadcast", RoomController, :broadcast
  end

  if Application.compile_env(:parlor, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: ParlorWeb.Telemetry
    end
  end
end
