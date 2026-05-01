defmodule OberCloudWeb.PageController do
  use OberCloudWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
