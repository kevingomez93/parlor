defmodule Parlor.Token do
  @moduledoc """
  JWT signing and verification for Parlor websocket authentication.
  """

  @doc """
  Verifies an HS256 JWT and returns its claims.
  """
  @spec verify(String.t()) :: {:ok, map()} | {:error, term()}
  def verify(token) when is_binary(token) do
    Joken.verify(token, signer())
  end

  @doc """
  Signs claims into an HS256 JWT. Useful for tests and backend integrations.
  """
  @spec sign(map()) :: {:ok, String.t(), map()} | {:error, term()}
  def sign(claims) when is_map(claims) do
    Joken.generate_and_sign(%{}, claims, signer())
  end

  defp signer do
    Joken.Signer.create("HS256", signing_secret())
  end

  defp signing_secret do
    Application.get_env(:parlor, :signing_secret) ||
      raise "PARLOR_SIGNING_SECRET is not configured"
  end
end
