defmodule OberCloudWeb.NodesLive do
  use OberCloudWeb, :live_view

  alias OberCloud.ControlPlane.Node

  @impl true
  def mount(_params, _session, socket) do
    actor = build_actor(socket.assigns[:current_user])
    {:ok, assign(socket, :nodes, list_nodes(actor))}
  end

  defp build_actor(nil), do: nil
  defp build_actor(%{} = u), do: Map.put(u, :type, :user)

  defp list_nodes(actor) do
    case Ash.read(Node, actor: actor) do
      {:ok, ns} -> ns
      _ -> []
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6">
      <h1 class="text-2xl font-semibold mb-4">Control Plane Nodes</h1>
      <table class="w-full border">
        <thead>
          <tr class="border-b">
            <th class="text-left p-2">Provider</th>
            <th class="text-left p-2">Role</th>
            <th class="text-left p-2">Status</th>
            <th class="text-left p-2">IP</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={n <- @nodes} class="border-b">
            <td class="p-2">{n.provider}</td>
            <td class="p-2">{n.role}</td>
            <td class="p-2">{n.status}</td>
            <td class="p-2">{n.ip_address}</td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end
end
