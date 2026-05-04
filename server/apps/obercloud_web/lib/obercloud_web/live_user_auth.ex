defmodule OberCloudWeb.LiveUserAuth do
  @moduledoc """
  on_mount hooks gating LiveView access by current_user.

  AshAuthentication.Phoenix doesn't expose a `use` macro for this
  module in 2.x; we just implement Phoenix.LiveView.on_mount/4 directly.
  The router still uses {AshAuthentication.Phoenix.LiveSession, :default}
  to populate `socket.assigns.current_user` from the session.
  """

  def on_mount(:live_user_required, _params, _session, socket) do
    if socket.assigns[:current_user],
      do: {:cont, socket},
      else: {:halt, Phoenix.LiveView.redirect(socket, to: "/sign-in")}
  end

  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user],
      do: {:halt, Phoenix.LiveView.redirect(socket, to: "/")},
      else: {:cont, socket}
  end
end
