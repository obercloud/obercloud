defmodule OberCloud.Auth do
  use Ash.Domain, otp_app: :obercloud, extensions: [AshJsonApi.Domain]

  resources do
    resource OberCloud.Auth.ApiKey
  end

  json_api do
    routes do
      base_route "/api_keys", OberCloud.Auth.ApiKey do
        get :read
        index :read
        post :create
        delete :destroy
      end
    end
  end
end
