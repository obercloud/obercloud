defmodule OberCloudWeb.DashboardLive do
  use OberCloudWeb, :live_view

  alias OberCloud.{Accounts.Org, Projects.Project, ControlPlane.Node}

  @impl true
  def mount(_params, _session, socket) do
    actor = build_actor(socket.assigns[:current_user])

    {:ok,
     socket
     |> assign(:orgs_count, count(Org, actor))
     |> assign(:projects_count, count(Project, actor))
     |> assign(:nodes_count, count(Node, actor))}
  end

  defp build_actor(nil), do: nil
  defp build_actor(%{} = user), do: Map.put(user, :type, :user)

  defp count(resource, actor) do
    case Ash.count(resource, actor: actor) do
      {:ok, n} -> n
      _ -> 0
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-3 gap-4 p-6">
      <.stat title="Orgs" value={@orgs_count} />
      <.stat title="Projects" value={@projects_count} />
      <.stat title="Nodes" value={@nodes_count} />
    </div>
    """
  end

  attr :title, :string, required: true
  attr :value, :integer, required: true

  defp stat(assigns) do
    ~H"""
    <div class="rounded border p-4">
      <p class="text-sm text-gray-500">{@title}</p>
      <p class="text-3xl font-semibold">{@value}</p>
    </div>
    """
  end
end
