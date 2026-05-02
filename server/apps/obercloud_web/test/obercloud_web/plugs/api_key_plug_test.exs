defmodule OberCloudWeb.Plugs.ApiKeyPlugTest do
  use OberCloudWeb.ConnCase, async: true
  alias OberCloudWeb.Plugs.ApiKeyPlug
  alias OberCloud.{Auth.ApiKey, Accounts.Org}

  setup %{conn: conn} do
    {:ok, org} = Ash.create(Org, %{name: "Acme", slug: "acme"}, authorize?: false)

    {:ok, %{plaintext: pt}} =
      ApiKey.create_with_plaintext(%{name: "k", org_id: org.id, role: "org:admin"})

    {:ok, conn: conn, plaintext: pt}
  end

  test "sets actor on valid bearer token", %{conn: conn, plaintext: pt} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer #{pt}")
      |> ApiKeyPlug.call(ApiKeyPlug.init([]))

    assert conn.assigns.current_actor.type == :api_key
    assert conn.assigns.current_actor.role == "org:admin"
  end

  test "halts with 401 on missing token", %{conn: conn} do
    conn = ApiKeyPlug.call(conn, ApiKeyPlug.init([]))
    assert conn.status == 401
    assert conn.halted
  end

  test "halts with 401 on invalid token", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer obk_garbage")
      |> ApiKeyPlug.call(ApiKeyPlug.init([]))

    assert conn.status == 401
  end
end
