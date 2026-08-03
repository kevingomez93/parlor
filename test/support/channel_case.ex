defmodule ParlorWeb.ChannelCase do
  @moduledoc """
  Test case for channel tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest
      import ParlorWeb.ChannelCase, only: [build_token: 0, build_token: 1]

      @endpoint ParlorWeb.Endpoint
    end
  end

  setup _tags do
    {:ok, token: build_token()}
  end

  def build_token(overrides \\ %{}) do
    claims =
      Map.merge(
        %{
          "sub" => "user-#{System.unique_integer([:positive])}",
          "meta" => %{"name" => "Test User"}
        },
        overrides
      )

    {:ok, token, _} = Parlor.Token.sign(claims)
    token
  end
end
