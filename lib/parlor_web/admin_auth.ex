defmodule ParlorWeb.AdminAuth do
  @moduledoc false

  import Phoenix.LiveView

  def on_mount(:default, _params, session, socket) do
    if session["admin"] do
      {:cont, socket}
    else
      {:halt, redirect(socket, to: "/")}
    end
  end
end
