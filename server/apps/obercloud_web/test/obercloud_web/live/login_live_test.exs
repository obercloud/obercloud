defmodule OberCloudWeb.LoginLiveTest do
  use OberCloudWeb.ConnCase, async: true

  test "GET /sign-in returns 200", %{conn: conn} do
    conn = get(conn, "/sign-in")
    assert conn.status == 200
  end

  test "redirects unauthenticated users to /sign-in", %{conn: conn} do
    conn = get(conn, "/")
    assert redirected_to(conn) =~ "/sign-in"
  end
end
