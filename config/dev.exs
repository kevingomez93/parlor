import Config

config :parlor, Parlor.Repo,
  username: "parlor",
  password: "parlor",
  hostname: "localhost",
  database: "parlor_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :parlor, ParlorWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "0GqCUeRWA40i+h29alZBT5e+mxgBPB2BQkkSTUeGK2gHboP3tskjDnz6mZH2Q0+U",
  watchers: []

config :parlor, dev_routes: true

config :logger, :default_formatter, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
