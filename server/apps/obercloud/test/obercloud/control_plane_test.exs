defmodule OberCloud.ControlPlaneTest do
  use OberCloud.DataCase, async: true
  alias OberCloud.ControlPlane.{Node, ProviderCredential}

  setup do
    {:ok, org} = Ash.create(OberCloud.Accounts.Org, %{name: "Acme", slug: "acme"}, authorize?: false)
    {:ok, org: org}
  end

  describe "nodes" do
    test "creates a node in provisioning state" do
      assert {:ok, node} =
               Node
               |> Ash.Changeset.for_create(:create, %{
                 provider: "hetzner",
                 role: "primary",
                 status: "provisioning",
                 provider_metadata: %{"region" => "nbg1", "server_type" => "cx21"}
               })
               |> Ash.create(authorize?: false)

      assert node.status == "provisioning"
      assert node.provider == "hetzner"
    end

    test "rejects invalid provider" do
      assert {:error, _} =
               Node
               |> Ash.Changeset.for_create(:create, %{
                 provider: "aws",
                 role: "primary",
                 status: "provisioning"
               })
               |> Ash.create(authorize?: false)
    end

    test "rejects invalid status" do
      assert {:error, _} =
               Node
               |> Ash.Changeset.for_create(:create, %{
                 provider: "hetzner",
                 role: "primary",
                 status: "wat"
               })
               |> Ash.create(authorize?: false)
    end
  end

  describe "provider credentials" do
    test "stores encrypted credentials and decrypts back", %{org: org} do
      assert {:ok, cred} =
               ProviderCredential
               |> Ash.Changeset.for_create(:create, %{
                 org_id: org.id,
                 provider: "hetzner",
                 plaintext_credentials: %{"api_token" => "test-token-12345"}
               })
               |> Ash.create(authorize?: false)

      reloaded = Ash.get!(ProviderCredential, cred.id, authorize?: false)
      assert {:ok, %{"api_token" => "test-token-12345"}} =
               ProviderCredential.decrypted_credentials(reloaded)
      refute reloaded.credentials_enc =~ "test-token-12345"
    end
  end
end
