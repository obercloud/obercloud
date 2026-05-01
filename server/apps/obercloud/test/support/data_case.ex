defmodule OberCloud.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias OberCloud.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import OberCloud.DataCase
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(OberCloud.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  Used by ConnCase and other test modules that need sandbox access.
  """
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(OberCloud.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end
end
