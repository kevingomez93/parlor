defmodule ParlorWeb.Plugs.RateLimit do
  @moduledoc """
  Applies fixed-window rate limiting to HTTP API requests.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    {limit, window_ms} = Application.get_env(:parlor, :http_rate_limit, {120, 60_000})
    key = rate_limit_key(conn)

    if Parlor.RateLimiter.allow?(key, limit, window_ms) do
      conn
    else
      retry_after = max(div(window_ms, 1000), 1)

      conn
      |> put_resp_header("retry-after", Integer.to_string(retry_after))
      |> put_status(:too_many_requests)
      |> Phoenix.Controller.json(%{error: "rate_limited"})
      |> halt()
    end
  end

  defp rate_limit_key(conn) do
    case get_req_header(conn, "x-api-key") do
      [api_key | _] -> {:http, :api_key, api_key}
      _ -> {:http, :ip, conn.remote_ip}
    end
  end
end
