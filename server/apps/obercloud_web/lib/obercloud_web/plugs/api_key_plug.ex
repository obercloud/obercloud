defmodule OberCloudWeb.Plugs.ApiKeyPlug do
  import Plug.Conn
  alias OberCloud.Auth.ApiKey

  def init(opts), do: opts

  def call(conn, _opts) do
    with [bearer] <- get_req_header(conn, "authorization"),
         "Bearer " <> token <- bearer,
         {:ok, key} <- ApiKey.verify(token) do
      Task.start(fn ->
        key |> Ash.Changeset.for_update(:touch_last_used) |> Ash.update(authorize?: false)
      end)

      actor = %{type: :api_key, id: key.id, org_id: key.org_id, role: key.role}

      conn
      |> assign(:current_actor, actor)
      |> Ash.PlugHelpers.set_actor(actor)
    else
      _ -> unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, ~s({"error": "unauthorized"}))
    |> halt()
  end
end
