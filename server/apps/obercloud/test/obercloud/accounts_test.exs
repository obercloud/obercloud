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

  describe "users" do
    test "registers a user with email and password" do
      {:ok, user} =
        OberCloud.Accounts.User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "alice@example.com",
          name: "Alice",
          password: "supersecret123",
          password_confirmation: "supersecret123"
        })
        |> Ash.create()

      assert "#{user.email}" == "alice@example.com"
      refute user.hashed_password == "supersecret123"
    end

    test "rejects mismatched password confirmation" do
      assert {:error, _} =
               OberCloud.Accounts.User
               |> Ash.Changeset.for_create(:register_with_password, %{
                 email: "bob@example.com",
                 name: "Bob",
                 password: "secret123456",
                 password_confirmation: "different12345"
               })
               |> Ash.create()
    end

    test "signs in with valid credentials" do
      {:ok, _} =
        OberCloud.Accounts.User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "carol@example.com",
          name: "Carol",
          password: "supersecret123",
          password_confirmation: "supersecret123"
        })
        |> Ash.create()

      assert {:ok, [user]} =
               OberCloud.Accounts.User
               |> Ash.Query.for_read(:sign_in_with_password, %{
                 email: "carol@example.com",
                 password: "supersecret123"
               })
               |> Ash.read()

      assert "#{user.email}" == "carol@example.com"
    end
  end

  describe "memberships" do
    setup do
      {:ok, org} = Ash.create(OberCloud.Accounts.Org, %{name: "Acme", slug: "acme"})
      {:ok, user} =
        OberCloud.Accounts.User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "dan@example.com", name: "Dan",
          password: "secret123456", password_confirmation: "secret123456"
        })
        |> Ash.create()
      {:ok, org: org, user: user}
    end

    test "creates a membership with a role", %{org: org, user: user} do
      assert {:ok, m} =
               OberCloud.Accounts.Membership
               |> Ash.Changeset.for_create(:create, %{
                 org_id: org.id, user_id: user.id, role: "org:owner"
               })
               |> Ash.create()
      assert m.role == "org:owner"
    end

    test "rejects invalid role", %{org: org, user: user} do
      assert {:error, _} =
               OberCloud.Accounts.Membership
               |> Ash.Changeset.for_create(:create, %{
                 org_id: org.id, user_id: user.id, role: "invalid"
               })
               |> Ash.create()
    end

    test "rejects duplicate user/org pair", %{org: org, user: user} do
      p = %{org_id: org.id, user_id: user.id, role: "org:member"}
      {:ok, _} = Ash.create(OberCloud.Accounts.Membership, p)
      assert {:error, _} = Ash.create(OberCloud.Accounts.Membership, p)
    end
  end
end
