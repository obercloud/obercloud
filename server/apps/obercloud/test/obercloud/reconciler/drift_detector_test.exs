defmodule OberCloud.Reconciler.DriftDetectorTest do
  use OberCloud.DataCase
  use Oban.Testing, repo: OberCloud.Repo

  alias OberCloud.Reconciler.{DesiredState, DriftDetector}
  alias OberCloud.Accounts.Org

  test "enqueues reconcile jobs for drifted resources" do
    {:ok, org} = Ash.create(Org, %{name: "A", slug: "a"}, authorize?: false)

    {:ok, ds} =
      DesiredState
      |> Ash.Changeset.for_create(:create, %{
        org_id: org.id,
        resource_type: "node",
        resource_id: Ecto.UUID.generate(),
        spec: %{}
      })
      |> Ash.create()

    {:ok, _} =
      ds
      |> Ash.Changeset.for_update(:mark_drifted)
      |> Ash.update(authorize?: false)

    assert :ok = perform_job(DriftDetector, %{})
    assert_enqueued worker: OberCloud.Reconciler.ReconcileWorker
  end
end
