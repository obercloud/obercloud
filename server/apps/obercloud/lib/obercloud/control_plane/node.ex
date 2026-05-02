defmodule OberCloud.ControlPlane.Node do
  use Ash.Resource,
    otp_app: :obercloud,
    domain: OberCloud.ControlPlane,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  postgres do
    table "nodes"
    repo OberCloud.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :provider, :string, allow_nil?: false, public?: true
    attribute :provider_resource_id, :string, public?: true
    attribute :provider_metadata, :map, default: %{}, public?: true
    attribute :ip_address, :string, public?: true
    attribute :role, :string, allow_nil?: false, public?: true
    attribute :status, :string, allow_nil?: false, public?: true
    attribute :joined_at, :utc_datetime, public?: true

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  validations do
    validate attribute_in(:provider, ~w(hetzner digitalocean))
    validate attribute_in(:role, ~w(primary standby worker))
    validate attribute_in(:status, ~w(provisioning ready degraded decommissioned))
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:provider, :provider_resource_id, :provider_metadata,
              :ip_address, :role, :status]
      primary? true
    end

    update :update do
      accept [:provider_resource_id, :provider_metadata, :ip_address,
              :status, :joined_at]
      primary? true
    end

    update :mark_ready do
      accept [:ip_address, :provider_resource_id]
      change set_attribute(:status, "ready")
      change set_attribute(:joined_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if actor_present()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if {OberCloud.Auth.Checks.ActorHasRole, role: "system:owner"}
    end
  end

  json_api do
    type "node"
  end
end
