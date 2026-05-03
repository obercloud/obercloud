defmodule OberCloudWeb.DashboardLive do
  use OberCloudWeb, :live_view

  def mount(_params, _session, socket), do: {:ok, socket}

  def render(assigns) do
    ~H"""
    <div>Dashboard placeholder (Task 23 fills this in)</div>
    """
  end
end
