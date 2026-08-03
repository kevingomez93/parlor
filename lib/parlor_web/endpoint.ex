defmodule ParlorWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :parlor

  @session_options [
    store: :cookie,
    key: "_parlor_key",
    signing_salt: "dv75yfEp",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  socket "/socket", ParlorWeb.RoomSocket,
    websocket: true,
    longpoll: false

  plug Plug.Static,
    at: "/",
    from: :parlor,
    gzip: not code_reloading?,
    only: ParlorWeb.static_paths(),
    raise_on_missing_only: code_reloading?

  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug ParlorWeb.Router
end
