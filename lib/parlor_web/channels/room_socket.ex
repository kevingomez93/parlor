defmodule ParlorWeb.RoomSocket do
  @moduledoc false

  use Phoenix.Socket

  channel "room:*", ParlorWeb.RoomChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    authenticate(token, socket)
  end

  def connect(_params, socket, _connect_info) do
    if auth_mode() == :none do
      {:ok, assign(socket, :current_user, dev_user())}
    else
      :error
    end
  end

  @impl true
  def id(_socket), do: nil

  defp authenticate(token, socket) do
    case auth_mode() do
      :none ->
        {:ok, assign(socket, :current_user, dev_user())}

      :jwt ->
        case Parlor.Token.verify(token) do
          {:ok, claims} ->
            user = %{
              id: Map.get(claims, "sub"),
              rooms: null_to_nil(Map.get(claims, "rooms")),
              meta: null_to_nil(Map.get(claims, "meta")) || %{}
            }

            if is_binary(user.id) and user.id != "" do
              {:ok, assign(socket, :current_user, user)}
            else
              :error
            end

          {:error, _reason} ->
            :error
        end
    end
  end

  defp auth_mode do
    Application.get_env(:parlor, :auth_mode, :jwt)
  end

  defp dev_user do
    %{id: "dev-user", rooms: nil, meta: %{}}
  end

  defp null_to_nil(:null), do: nil
  defp null_to_nil(value), do: value
end
