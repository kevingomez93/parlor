defmodule ParlorWeb.RateLimitPlugTest do
  use ParlorWeb.ConnCase, async: false

  @api_key "test-api-key"

  setup do
    Application.put_env(:parlor, :http_rate_limit, {2, 60_000})
    Parlor.RateLimiter.reset({:http, :api_key, @api_key})

    on_exit(fn ->
      Application.put_env(:parlor, :http_rate_limit, {120, 60_000})
      Parlor.RateLimiter.reset({:http, :api_key, @api_key})
    end)

    :ok
  end

  test "returns 429 when rate limited", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-api-key", @api_key)
      |> get(~p"/api/rooms")

    assert conn.status == 200

    conn =
      build_conn()
      |> put_req_header("x-api-key", @api_key)
      |> get(~p"/api/rooms")

    assert conn.status == 200

    conn =
      build_conn()
      |> put_req_header("x-api-key", @api_key)
      |> get(~p"/api/rooms")

    assert conn.status == 429
    assert json_response(conn, 429)["error"] == "rate_limited"
    assert get_resp_header(conn, "retry-after") != []
  end

  test "health endpoint is not rate limited", %{conn: conn} do
    for _ <- 1..5 do
      conn = get(conn, ~p"/api/health")
      assert conn.status == 200
    end
  end
end
