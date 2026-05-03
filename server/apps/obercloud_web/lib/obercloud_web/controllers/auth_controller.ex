defmodule OberCloudWeb.AuthController do
  use OberCloudWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, _activity, user, _token) do
    conn
    |> store_in_session(user)
    |> assign(:current_user, user)
    |> redirect(to: "/")
  end

  def failure(conn, _activity, _reason) do
    conn
    |> put_flash(:error, "Sign in failed")
    |> redirect(to: "/sign-in")
  end

  def sign_out(conn, _params) do
    conn |> Plug.Conn.clear_session() |> redirect(to: "/sign-in")
  end
end
