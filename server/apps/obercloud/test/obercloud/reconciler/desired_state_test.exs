defmodule OberCloud.Reconciler.DesiredStateTest do
  use OberCloud.DataCase, async: true
  alias OberCloud.Reconciler.DesiredState

  setup do
    {:ok, org} = Ash.create(OberCloud.Accounts.Org, %{name: "Acme", slug: "acme"}, authorize?: false)
    {:ok, org: org}
  end

  test "creates pending desired_state row", %{org: org} do
    {:ok, ds} =
      DesiredState
      |> Ash.Changeset.for_create(:create, %{
        org_id: org.id,
        resource_type: "node",
        resource_id: Ecto.UUID.generate(),
        spec: %{"region" => "nbg1"}
      })
      |> Ash.create(authorize?: false)

    assert ds.reconcile_status == "pending"
  end

  test "transitions to ready", %{org: org} do
    {:ok, ds} =
      DesiredState
      |> Ash.Changeset.for_create(:create, %{
        org_id: org.id, resource_type: "node",
        resource_id: Ecto.UUID.generate(), spec: %{}
      })
      |> Ash.create(authorize?: false)

    {:ok, ready} = ds |> Ash.Changeset.for_update(:mark_ready) |> Ash.update(authorize?: false)
    assert ready.reconcile_status == "ready"
    assert ready.reconciled_at
  end
end
