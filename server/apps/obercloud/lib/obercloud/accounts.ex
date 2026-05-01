defmodule OberCloud.Accounts do
  use Ash.Domain, otp_app: :obercloud, extensions: [AshJsonApi.Domain]

  resources do
    resource OberCloud.Accounts.Org
    resource OberCloud.Accounts.User
    resource OberCloud.Accounts.Token
    resource OberCloud.Accounts.Membership
  end

  json_api do
    routes do
      base_route "/orgs", OberCloud.Accounts.Org do
        get :read
        index :read
        post :create
        patch :update
        delete :destroy
      end
    end
  end
end
