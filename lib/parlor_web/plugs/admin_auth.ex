defmodule ParlorWeb.Plugs.AdminAuth do
  @moduledoc """
  Protects admin routes with HTTP basic auth and sets a session flag for LiveView.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    username = Application.get_env(:parlor, :admin_user, "admin")
    password = Application.get_env(:parlor, :admin_password, "admin")

    case Plug.BasicAuth.basic_auth(conn, username: username, password: password) do
      %Plug.Conn{halted: true} = conn ->
        conn

      conn ->
        put_session(conn, :admin, true)
    end
  end
end
