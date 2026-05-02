defmodule OberCloud.Accounts.Org do
  use Ash.Resource,
    otp_app: :obercloud,
    domain: OberCloud.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  postgres do
    table "organizations"
    repo OberCloud.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
      constraints match: ~r/\A[a-z0-9][a-z0-9\-]{0,62}[a-z0-9]?\z/
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :memberships, OberCloud.Accounts.Membership
  end

  identities do
    identity :unique_slug, [:slug]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :slug]
      primary? true
    end

    update :update do
      accept [:name]
      primary? true
    end
  end

  policies do
    # On Org, "actor in this org" is expressed as a filter:
    # - API key actors carry org_id directly → match by id
    # - User actors authenticate via Membership → match orgs they belong to
    policy action_type(:read) do
      authorize_if expr(id == ^actor(:org_id))
      authorize_if expr(exists(memberships, user_id == ^actor(:id)))
    end

    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action_type([:update, :destroy]) do
      authorize_if {OberCloud.Auth.Checks.ActorHasRole, role: "org:owner"}
    end
  end

  json_api do
    type "org"
  end
end
