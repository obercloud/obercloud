defmodule OberCloud.ProjectsTest do
  use OberCloud.DataCase, async: true
  alias OberCloud.Projects.Project

  setup do
    {:ok, org} = Ash.create(OberCloud.Accounts.Org, %{name: "Acme", slug: "acme"})
    {:ok, org: org}
  end

  test "creates a project", %{org: org} do
    assert {:ok, p} =
             Project
             |> Ash.Changeset.for_create(:create, %{
               name: "Production",
               slug: "production",
               org_id: org.id
             })
             |> Ash.create()

    assert p.slug == "production"
  end

  test "enforces slug uniqueness within an org", %{org: org} do
    params = %{name: "Production", slug: "production", org_id: org.id}
    {:ok, _} = Ash.create(Project, params)
    assert {:error, _} = Ash.create(Project, params)
  end

  test "allows same slug across different orgs", %{org: org} do
    {:ok, org2} = Ash.create(OberCloud.Accounts.Org, %{name: "Other", slug: "other"})
    {:ok, _} = Ash.create(Project, %{name: "Prod", slug: "prod", org_id: org.id})
    assert {:ok, _} = Ash.create(Project, %{name: "Prod", slug: "prod", org_id: org2.id})
  end
end
