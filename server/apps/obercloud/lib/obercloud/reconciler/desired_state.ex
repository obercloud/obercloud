defmodule OberCloud.Reconciler.DesiredState do
  use Ash.Resource,
    otp_app: :obercloud,
    domain: OberCloud.Reconciler,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "desired_state"
    repo OberCloud.Repo
    references do
      reference :org, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :resource_type, :string, allow_nil?: false, public?: true
    attribute :resource_id, :uuid, allow_nil?: false, public?: true

    attribute :spec, :map do
      allow_nil? false
      default %{}
      public? true
    end

    attribute :reconcile_status, :string do
      allow_nil? false
      default "pending"
      public? true
    end

    attribute :reconciled_at, :utc_datetime, public?: true
    attribute :error, :string, public?: true

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :org, OberCloud.Accounts.Org, allow_nil?: false, public?: true
    belongs_to :project, OberCloud.Projects.Project, public?: true
  end

  validations do
    validate attribute_in(:reconcile_status, ~w(pending reconciling ready failed drifted))
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:resource_type, :resource_id, :org_id, :project_id, :spec]
      primary? true
    end

    update :update_spec do
      accept [:spec]
      change set_attribute(:reconcile_status, "pending")
      change set_attribute(:error, nil)
    end

    update :mark_reconciling do
      change set_attribute(:reconcile_status, "reconciling")
    end

    update :mark_ready do
      change set_attribute(:reconcile_status, "ready")
      change set_attribute(:reconciled_at, &DateTime.utc_now/0)
      change set_attribute(:error, nil)
    end

    update :mark_failed do
      accept [:error]
      change set_attribute(:reconcile_status, "failed")
    end

    update :mark_drifted do
      change set_attribute(:reconcile_status, "drifted")
    end
  end
end
