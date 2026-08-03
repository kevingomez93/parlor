defmodule ParlorWeb.ConnCase do
  @moduledoc """
  Test case for controller and connection tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint ParlorWeb.Endpoint

      use ParlorWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import ParlorWeb.ConnCase
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
