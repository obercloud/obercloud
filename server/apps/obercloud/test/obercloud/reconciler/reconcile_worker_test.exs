defmodule OberCloud.Reconciler.ReconcileWorkerTest do
  use OberCloud.DataCase
  use Oban.Testing, repo: OberCloud.Repo

  alias OberCloud.Reconciler.{DesiredState, ReconcileWorker}
  alias OberCloud.Accounts.Org

  setup do
    {:ok, org} = Ash.create(Org, %{name: "A", slug: "a"}, authorize?: false)

    {:ok, ds} =
      DesiredState
      |> Ash.Changeset.for_create(:create, %{
        org_id: org.id,
        resource_type: "node",
        resource_id: Ecto.UUID.generate(),
        spec: %{
          "provider" => "hetzner",
          "resource_type" => "node",
          "name" => "n1",
          "region" => "nbg1",
          "server_type" => "cx21",
          "image" => "ubuntu-22.04"
        }
      })
      |> Ash.create()

    {:ok, ds: ds}
  end

  test "marks desired_state as ready after success", %{ds: ds} do
    assert :ok = perform_job(ReconcileWorker, %{"desired_state_id" => ds.id})
    reloaded = Ash.get!(DesiredState, ds.id, authorize?: false)
    assert reloaded.reconcile_status == "ready"
  end
end
