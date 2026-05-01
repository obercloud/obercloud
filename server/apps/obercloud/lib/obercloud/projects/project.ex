defmodule OberCloud.Projects.Project do
  use Ash.Resource,
    otp_app: :obercloud,
    domain: OberCloud.Projects,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    table "projects"
    repo OberCloud.Repo
    references do
      reference :org, on_delete: :delete
    end
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
    belongs_to :org, OberCloud.Accounts.Org, allow_nil?: false, public?: true
  end

  identities do
    identity :unique_slug_per_org, [:org_id, :slug]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :slug, :org_id]
      primary? true
    end

    update :update do
      accept [:name]
      primary? true
    end
  end

  json_api do
    type "project"
  end
end
