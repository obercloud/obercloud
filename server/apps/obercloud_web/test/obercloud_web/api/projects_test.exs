defmodule OberCloudWeb.Api.ProjectsTest do
  use OberCloudWeb.ConnCase, async: true
  alias OberCloud.{Auth.ApiKey, Accounts.Org}

  setup %{conn: conn} do
    {:ok, org} = Ash.create(Org, %{name: "A", slug: "a"}, authorize?: false)

    {:ok, %{plaintext: pt}} =
      ApiKey.create_with_plaintext(%{name: "k", org_id: org.id, role: "org:admin"})

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{pt}")
      |> put_req_header("accept", "application/vnd.api+json")
      |> put_req_header("content-type", "application/vnd.api+json")

    {:ok, conn: conn, org: org}
  end

  test "create + list projects", %{conn: conn, org: org} do
    payload = %{
      "data" => %{
        "type" => "project",
        "attributes" => %{"name" => "P", "slug" => "p", "org_id" => org.id}
      }
    }

    create_resp = post(conn, "/api/projects", payload)
    project_id = json_response(create_resp, 201)["data"]["id"]

    list_resp = get(conn, "/api/projects")
    ids = Enum.map(json_response(list_resp, 200)["data"], & &1["id"])
    assert project_id in ids
  end

  test "rejects request without bearer token" do
    conn = build_conn() |> put_req_header("accept", "application/vnd.api+json")
    conn = get(conn, "/api/projects")
    assert conn.status == 401
  end
end
