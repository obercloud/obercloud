defmodule OberCloudWeb.ProjectsLive do
  use OberCloudWeb, :live_view

  alias OberCloud.Projects.Project

  @impl true
  def mount(_params, _session, socket) do
    actor = build_actor(socket.assigns[:current_user])
    {:ok, assign(socket, :projects, list_projects(actor))}
  end

  defp build_actor(nil), do: nil
  defp build_actor(%{} = u), do: Map.put(u, :type, :user)

  defp list_projects(actor) do
    case Ash.read(Project, actor: actor) do
      {:ok, ps} -> ps
      _ -> []
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6">
      <h1 class="text-2xl font-semibold mb-4">Projects</h1>
      <table class="w-full border">
        <thead>
          <tr class="border-b">
            <th class="text-left p-2">Name</th>
            <th class="text-left p-2">Slug</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={p <- @projects} class="border-b">
            <td class="p-2">{p.name}</td>
            <td class="p-2">{p.slug}</td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end
end
