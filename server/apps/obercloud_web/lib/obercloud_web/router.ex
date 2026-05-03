defmodule OberCloudWeb.Router do
  use OberCloudWeb, :router
  use AshAuthentication.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OberCloudWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json", "json-api"]
    plug OberCloudWeb.Plugs.ApiKeyPlug
  end

  scope "/api" do
    pipe_through :api
    forward "/", OberCloudWeb.ApiRouter
  end

  scope "/", OberCloudWeb do
    pipe_through :browser

    auth_routes_for OberCloud.Accounts.User, to: AuthController
    sign_out_route AuthController
    # sign_in_route brings its own live_session — cannot be nested
    sign_in_route(register_path: "/register")

    live_session :authenticated,
      on_mount: [{OberCloudWeb.LiveUserAuth, :live_user_required}] do
      live "/", DashboardLive
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:obercloud_web, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: OberCloudWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
