import Config

if System.get_env("PHX_SERVER") do
  config :parlor, ParlorWeb.Endpoint, server: true
end

config :parlor, ParlorWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() in [:dev, :prod] do
  auth_mode =
    case System.get_env("PARLOR_AUTH", if(config_env() == :dev, do: "none", else: "jwt")) do
      "none" -> :none
      _ -> :jwt
    end

  parlor_config = [
    auth_mode: auth_mode,
    room_ttl: String.to_integer(System.get_env("PARLOR_ROOM_TTL", "60000"))
  ]

  parlor_config =
    if secret = System.get_env("PARLOR_SIGNING_SECRET") do
      Keyword.put(parlor_config, :signing_secret, secret)
    else
      parlor_config
    end

  parlor_config =
    if api_key = System.get_env("PARLOR_API_KEY") do
      Keyword.put(parlor_config, :api_key, api_key)
    else
      parlor_config
    end

  parlor_config =
    if admin_user = System.get_env("PARLOR_ADMIN_USER") do
      Keyword.put(parlor_config, :admin_user, admin_user)
    else
      parlor_config
    end

  parlor_config =
    if admin_password = System.get_env("PARLOR_ADMIN_PASSWORD") do
      Keyword.put(parlor_config, :admin_password, admin_password)
    else
      parlor_config
    end

  parlor_config =
    if value = System.get_env("PARLOR_CHANNEL_RATE_LIMIT") do
      [limit, window_ms] = String.split(value, ",", parts: 2)

      Keyword.put(
        parlor_config,
        :channel_rate_limit,
        {String.to_integer(limit), String.to_integer(window_ms)}
      )
    else
      parlor_config
    end

  parlor_config =
    if value = System.get_env("PARLOR_HTTP_RATE_LIMIT") do
      [limit, window_ms] = String.split(value, ",", parts: 2)

      Keyword.put(
        parlor_config,
        :http_rate_limit,
        {String.to_integer(limit), String.to_integer(window_ms)}
      )
    else
      parlor_config
    end

  config :parlor, parlor_config
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  config :parlor, Parlor.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  # Clustering: set DNS_CLUSTER_QUERY so dns_cluster connects BEAM nodes, and use the
  # same RELEASE_COOKIE on every instance. Horde distributes room processes automatically.
  config :parlor, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :parlor, ParlorWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  unless System.get_env("PARLOR_SIGNING_SECRET") do
    raise "environment variable PARLOR_SIGNING_SECRET is missing"
  end

  unless System.get_env("PARLOR_API_KEY") do
    raise "environment variable PARLOR_API_KEY is missing"
  end
end
