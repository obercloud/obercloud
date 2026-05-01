defmodule OberCloud.ControlPlane do
  use Ash.Domain, otp_app: :obercloud, extensions: [AshJsonApi.Domain]

  resources do
    resource OberCloud.ControlPlane.Node
    resource OberCloud.ControlPlane.ProviderCredential
  end

  json_api do
    routes do
      base_route "/nodes", OberCloud.ControlPlane.Node do
        get :read
        index :read
      end
    end
  end
end
