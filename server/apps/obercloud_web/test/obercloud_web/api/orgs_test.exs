defmodule OberCloudWeb.Api.OrgsTest do
  use OberCloudWeb.ConnCase, async: true
  alias OberCloud.{Auth.ApiKey, Accounts.Org}

  setup %{conn: conn} do
    {:ok, org} = Ash.create(Org, %{name: "Acme", slug: "acme"}, authorize?: false)

    {:ok, %{plaintext: pt}} =
      ApiKey.create_with_plaintext(%{name: "k", org_id: org.id, role: "org:admin"})

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{pt}")
      |> put_req_header("accept", "application/vnd.api+json")
      |> put_req_header("content-type", "application/vnd.api+json")

    {:ok, conn: conn, org: org}
  end

  test "GET /api/orgs lists orgs", %{conn: conn, org: org} do
    conn = get(conn, "/api/orgs")
    body = json_response(conn, 200)
    assert Enum.any?(body["data"], fn o -> o["id"] == org.id end)
  end

  test "POST /api/orgs creates an org", %{conn: conn} do
    payload = %{
      "data" => %{
        "type" => "org",
        "attributes" => %{"name" => "New", "slug" => "new"}
      }
    }

    conn = post(conn, "/api/orgs", payload)
    assert json_response(conn, 201)["data"]["attributes"]["slug"] == "new"
  end
end
