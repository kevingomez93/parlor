defmodule Parlor.TokenTest do
  use ExUnit.Case, async: true

  alias Parlor.Token

  test "signs and verifies tokens" do
    {:ok, token, _} =
      Token.sign(%{
        "sub" => "user-1",
        "rooms" => ["lobby"],
        "meta" => %{"name" => "Alice"}
      })

    assert {:ok, claims} = Token.verify(token)
    assert claims["sub"] == "user-1"
    assert claims["rooms"] == ["lobby"]
    assert claims["meta"] == %{"name" => "Alice"}
  end

  test "rejects invalid tokens" do
    assert {:error, _} = Token.verify("not-a-token")
  end
end
