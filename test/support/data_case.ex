defmodule Parlor.DataCase do
  @moduledoc """
  Test case for database-backed tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Parlor.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Parlor.DataCase
    end
  end

  setup tags do
    Parlor.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Parlor.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end
end
