defmodule OberCloud.AccountsTest do
  use OberCloud.DataCase, async: true
  alias OberCloud.Accounts.Org

  describe "organizations" do
    test "creates an organization" do
      assert {:ok, org} =
               Org
               |> Ash.Changeset.for_create(:create, %{name: "Acme Corp", slug: "acme"})
               |> Ash.create()

      assert org.name == "Acme Corp"
      assert org.slug == "acme"
    end

    test "rejects duplicate slug" do
      params = %{name: "Acme", slug: "acme"}
      {:ok, _} = Ash.create(Org, params)
      assert {:error, _} = Ash.create(Org, params)
    end

    test "rejects invalid slug format" do
      assert {:error, _} = Ash.create(Org, %{name: "Acme", slug: "Has Spaces!"})
    end
  end
end
