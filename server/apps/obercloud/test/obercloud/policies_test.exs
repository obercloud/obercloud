defmodule OberCloud.PoliciesTest do
  use OberCloud.DataCase, async: true

  alias OberCloud.Accounts.{Org, Membership, User}
  alias OberCloud.Projects.Project

  setup do
    {:ok, org_a} = Ash.create(Org, %{name: "A", slug: "org-a"}, authorize?: false)
    {:ok, org_b} = Ash.create(Org, %{name: "B", slug: "org-b"}, authorize?: false)

    {:ok, alice} =
      User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "alice@a.com",
        name: "Alice",
        password: "secret123456",
        password_confirmation: "secret123456"
      })
      |> Ash.create()

    {:ok, _} =
      Ash.create(Membership, %{user_id: alice.id, org_id: org_a.id, role: "org:owner"},
        authorize?: false
      )

    actor = Map.put(alice, :type, :user)
    {:ok, alice: actor, org_a: org_a, org_b: org_b}
  end

  test "owner of org A can create projects in A", %{alice: alice, org_a: org_a} do
    assert {:ok, _} =
             Project
             |> Ash.Changeset.for_create(:create, %{name: "P", slug: "p", org_id: org_a.id})
             |> Ash.create(actor: alice)
  end

  test "owner of org A cannot create projects in B", %{alice: alice, org_b: org_b} do
    assert {:error, %Ash.Error.Forbidden{}} =
             Project
             |> Ash.Changeset.for_create(:create, %{name: "P", slug: "p", org_id: org_b.id})
             |> Ash.create(actor: alice)
  end

  test "API key with org:viewer cannot create projects", %{org_a: org_a} do
    actor = %{type: :api_key, org_id: org_a.id, role: "org:viewer"}

    assert {:error, %Ash.Error.Forbidden{}} =
             Project
             |> Ash.Changeset.for_create(:create, %{name: "P", slug: "p", org_id: org_a.id})
             |> Ash.create(actor: actor)
  end

  test "API key with org:admin can create projects", %{org_a: org_a} do
    actor = %{type: :api_key, org_id: org_a.id, role: "org:admin"}

    assert {:ok, _} =
             Project
             |> Ash.Changeset.for_create(:create, %{name: "P2", slug: "p2", org_id: org_a.id})
             |> Ash.create(actor: actor)
  end
end
