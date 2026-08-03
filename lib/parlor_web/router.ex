defmodule ParlorWeb.Router do
  use ParlorWeb, :router

  import Phoenix.LiveView.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug ParlorWeb.Plugs.ApiAuth
  end

  pipeline :api_rate_limit do
    plug ParlorWeb.Plugs.RateLimit
  end

  pipeline :admin do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ParlorWeb.Layouts, :root}
    plug :protect_from_forgery
    plug ParlorWeb.Plugs.AdminAuth
  end

  scope "/", ParlorWeb do
    pipe_through :api

    get "/", PageController, :index
  end

  scope "/api", ParlorWeb do
    pipe_through :api

    get "/health", HealthController, :index
  end

  scope "/api", ParlorWeb do
    pipe_through [:api, :api_auth, :api_rate_limit]

    get "/rooms", RoomController, :index
    get "/rooms/:id", RoomController, :show
    post "/rooms/:id/broadcast", RoomController, :broadcast
  end

  scope "/admin", ParlorWeb do
    pipe_through :admin

    live_session :admin, on_mount: {ParlorWeb.AdminAuth, :default} do
      live "/", AdminLive, :index
      live "/rooms/:id", AdminLive, :show
    end
  end

  if Application.compile_env(:parlor, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: ParlorWeb.Telemetry
    end
  end
end
