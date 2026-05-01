defmodule OberCloud.AuthTest do
  use OberCloud.DataCase, async: true
  alias OberCloud.Auth.ApiKey

  setup do
    {:ok, org} = Ash.create(OberCloud.Accounts.Org, %{name: "Acme", slug: "acme"})
    {:ok, org: org}
  end

  test "creates a key and returns the plaintext exactly once", %{org: org} do
    assert {:ok, %{api_key: key, plaintext: pt}} =
             ApiKey.create_with_plaintext(%{name: "CI", org_id: org.id, role: "org:admin"})
    assert String.starts_with?(pt, "obk_")
    refute key.key_hash == pt
  end

  test "verifies a valid key", %{org: org} do
    {:ok, %{plaintext: pt}} =
      ApiKey.create_with_plaintext(%{name: "k", org_id: org.id, role: "org:admin"})
    assert {:ok, _} = ApiKey.verify(pt)
  end

  test "rejects an invalid key" do
    assert {:error, :invalid_key} = ApiKey.verify("obk_garbage_value_xxx")
  end

  test "rejects a revoked key", %{org: org} do
    {:ok, %{api_key: k, plaintext: pt}} =
      ApiKey.create_with_plaintext(%{name: "k", org_id: org.id, role: "org:admin"})
    {:ok, _} = ApiKey.revoke(k)
    assert {:error, :invalid_key} = ApiKey.verify(pt)
  end
end
