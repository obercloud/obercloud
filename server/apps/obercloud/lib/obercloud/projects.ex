defmodule OberCloud.Projects do
  use Ash.Domain, otp_app: :obercloud, extensions: [AshJsonApi.Domain]

  resources do
    resource OberCloud.Projects.Project
  end

  json_api do
    routes do
      base_route "/projects", OberCloud.Projects.Project do
        get :read
        index :read
        post :create
        patch :update
        delete :destroy
      end
    end
  end
end
