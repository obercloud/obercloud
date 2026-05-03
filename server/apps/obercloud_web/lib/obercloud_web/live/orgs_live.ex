defmodule OberCloudWeb.OrgsLive do
  use OberCloudWeb, :live_view

  alias OberCloud.Accounts.Org

  @impl true
  def mount(_params, _session, socket) do
    actor = build_actor(socket.assigns[:current_user])
    {:ok, assign(socket, :orgs, list_orgs(actor)) |> assign(:actor, actor)}
  end

  defp build_actor(nil), do: nil
  defp build_actor(%{} = u), do: Map.put(u, :type, :user)

  defp list_orgs(actor) do
    case Ash.read(Org, actor: actor) do
      {:ok, orgs} -> orgs
      _ -> []
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6">
      <h1 class="text-2xl font-semibold mb-4">Organizations</h1>
      <table class="w-full border">
        <thead>
          <tr class="border-b">
            <th class="text-left p-2">Name</th>
            <th class="text-left p-2">Slug</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={org <- @orgs} class="border-b">
            <td class="p-2">{org.name}</td>
            <td class="p-2">{org.slug}</td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end
end
