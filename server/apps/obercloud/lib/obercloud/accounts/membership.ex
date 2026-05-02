defmodule OberCloud.Accounts.Membership do
  use Ash.Resource,
    otp_app: :obercloud,
    domain: OberCloud.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "memberships"
    repo OberCloud.Repo
    references do
      reference :org, on_delete: :delete
      reference :user, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :role, :string do
      allow_nil? false
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :org, OberCloud.Accounts.Org, allow_nil?: false, public?: true
    belongs_to :user, OberCloud.Accounts.User, allow_nil?: false, public?: true
  end

  identities do
    identity :unique_user_org, [:user_id, :org_id]
  end

  validations do
    validate attribute_in(:role, ~w(system:owner org:owner org:admin org:member org:viewer))
  end

  policies do
    policy action_type(:read) do
      authorize_if {OberCloud.Auth.Checks.ActorInOrg, []}
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if {OberCloud.Auth.Checks.ActorHasRole, role: "org:admin"}
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:role, :org_id, :user_id]
      primary? true
    end

    update :update do
      accept [:role]
      primary? true
    end
  end
end
