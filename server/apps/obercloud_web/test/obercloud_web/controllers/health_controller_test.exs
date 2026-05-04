defmodule OberCloudWeb.HealthControllerTest do
  use OberCloudWeb.ConnCase, async: true

  test "GET /health returns 200 ok without auth", %{conn: conn} do
    conn = get(conn, "/health")
    assert response(conn, 200) == "ok"
  end
end
