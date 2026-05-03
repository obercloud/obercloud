defmodule OberCloudWeb.ApiKeysLive do
  use OberCloudWeb, :live_view

  alias OberCloud.Auth.ApiKey

  @impl true
  def mount(_params, _session, socket) do
    actor = build_actor(socket.assigns[:current_user])
    {:ok, assign(socket, :keys, list_keys(actor))}
  end

  defp build_actor(nil), do: nil
  defp build_actor(%{} = u), do: Map.put(u, :type, :user)

  defp list_keys(actor) do
    case Ash.read(ApiKey, actor: actor) do
      {:ok, ks} -> ks
      _ -> []
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6">
      <h1 class="text-2xl font-semibold mb-4">API Keys</h1>
      <table class="w-full border">
        <thead>
          <tr class="border-b">
            <th class="text-left p-2">Name</th>
            <th class="text-left p-2">Prefix</th>
            <th class="text-left p-2">Role</th>
            <th class="text-left p-2">Last Used</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={k <- @keys} class="border-b">
            <td class="p-2">{k.name}</td>
            <td class="p-2 font-mono text-xs">{k.key_prefix}</td>
            <td class="p-2">{k.role}</td>
            <td class="p-2">{format_dt(k.last_used_at)}</td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  defp format_dt(nil), do: "—"
  defp format_dt(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
end
