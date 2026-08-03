defmodule Parlor.Repo do
  use Ecto.Repo,
    otp_app: :parlor,
    adapter: Ecto.Adapters.Postgres
end
