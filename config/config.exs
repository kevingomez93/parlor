import Config

config :parlor,
  ecto_repos: [Parlor.Repo],
  generators: [timestamp_type: :utc_datetime],
  signing_secret: "dev-signing-secret-change-me",
  api_key: "dev-api-key-change-me",
  room_ttl: 60_000,
  yjs_flush_size: 400,
  auth_mode: :none,
  channel_rate_limit: {200, 10_000},
  http_rate_limit: {120, 60_000},
  admin_user: "admin",
  admin_password: "admin"

config :parlor, ParlorWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: ParlorWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Parlor.PubSub,
  live_view: [signing_salt: "nojlF0oV"]

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
