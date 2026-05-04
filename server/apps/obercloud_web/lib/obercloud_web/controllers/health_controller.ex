defmodule OberCloudWeb.HealthController do
  @moduledoc """
  Liveness/readiness endpoint hit by `obercloud init` and any external
  load balancer to determine when the control plane is up. Deliberately
  unauthenticated and dependency-light: a 200 here only means the BEAM
  process accepted a connection, not that any backing service is healthy.
  Add deeper checks (DB ping, Oban queue) here if/when the operational
  story calls for them.
  """
  use OberCloudWeb, :controller

  def index(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "ok")
  end
end
