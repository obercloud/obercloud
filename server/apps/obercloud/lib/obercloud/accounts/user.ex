defmodule OberCloud.Accounts.User do
  use Ash.Resource,
    otp_app: :obercloud,
    domain: OberCloud.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication]

  postgres do
    table "users"
    repo OberCloud.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string, allow_nil?: false, public?: true

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :hashed_password, :string, allow_nil?: false, sensitive?: true

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_email, [:email]
  end

  authentication do
    tokens do
      enabled? true
      token_resource OberCloud.Accounts.Token
      signing_secret fn _, _ ->
        {:ok, Application.fetch_env!(:obercloud, :token_signing_secret)}
      end
    end

    strategies do
      password :password do
        identity_field :email
        hashed_password_field :hashed_password
        confirmation_required? true
        register_action_accept [:name]
      end
    end
  end

  actions do
    defaults [:read]
  end
end
