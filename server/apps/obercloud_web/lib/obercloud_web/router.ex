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

  # Plain unauthenticated health check. Used by `obercloud init`'s
  # wait_for_health poller and by external load balancers / uptime
  # monitors. No pipeline — no session fetch, no CSRF, no auth.
  scope "/", OberCloudWeb do
    get "/health", HealthController, :index
  end

  scope "/api" do
    pipe_through :api
    forward "/", OberCloudWeb.ApiRouter
  end

  scope "/", OberCloudWeb do
    pipe_through :browser

    auth_routes OberCloudWeb.AuthController, OberCloud.Accounts.User, path: "/auth"
    sign_out_route AuthController
    # sign_in_route brings its own live_session — cannot be nested.
    # auth_routes_prefix MUST match the path passed to auth_routes/3 above,
    # otherwise the rendered sign-in form has no POST target and the page
    # appears blank.
    sign_in_route(register_path: "/register", auth_routes_prefix: "/auth")

    ash_authentication_live_session :authenticated,
      on_mount: [{OberCloudWeb.LiveUserAuth, :live_user_required}] do
      live "/", DashboardLive
      live "/orgs", OrgsLive
      live "/projects", ProjectsLive
      live "/nodes", NodesLive
      live "/api_keys", ApiKeysLive
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
