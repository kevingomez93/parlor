import Config

config :parlor,
  generators: [timestamp_type: :utc_datetime],
  signing_secret: "dev-signing-secret-change-me",
  api_key: "dev-api-key-change-me",
  room_ttl: 60_000,
  auth_mode: :none

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
