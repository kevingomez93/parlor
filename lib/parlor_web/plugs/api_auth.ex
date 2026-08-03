defmodule ParlorWeb.Plugs.ApiAuth do
  @moduledoc """
  Validates the `x-api-key` header for server-to-server HTTP requests.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    expected = Application.get_env(:parlor, :api_key)

    case get_req_header(conn, "x-api-key") do
      [key] when is_binary(expected) and key == expected ->
        conn

      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "unauthorized"})
        |> halt()
    end
  end
end
