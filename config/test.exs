import Config

config :parlor,
  signing_secret: "test-signing-secret",
  api_key: "test-api-key",
  room_ttl: 100,
  auth_mode: :jwt

config :parlor, ParlorWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "15J/IefgncP5aJMoq8lSV9Ws8r/z3pRKJdQjW8ZTpijUhTJ74s3ZQdiGKgAOwMw1",
  server: false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime
config :phoenix, sort_verified_routes_query_params: true
