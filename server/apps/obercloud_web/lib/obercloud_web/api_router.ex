defmodule OberCloudWeb.ApiRouter do
  # The open_api: "/open_api" option requires the open_api_spex dep.
  # Skipping for P0; can be added later if needed.
  use AshJsonApi.Router,
    domains: [
      OberCloud.Accounts,
      OberCloud.Projects,
      OberCloud.ControlPlane,
      OberCloud.Auth
    ]
end
