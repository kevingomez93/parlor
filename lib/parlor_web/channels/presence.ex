defmodule ParlorWeb.Presence do
  @moduledoc """
  Provides presence tracking for room channels.
  """

  use Phoenix.Presence,
    otp_app: :parlor,
    pubsub_server: Parlor.PubSub
end
