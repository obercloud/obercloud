defmodule OberCloud.ControlPlane.ProviderCredential do
  use Ash.Resource,
    otp_app: :obercloud,
    domain: OberCloud.ControlPlane,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "provider_credentials"
    repo OberCloud.Repo
    references do
      reference :org, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :provider, :string, allow_nil?: false, public?: true
    attribute :credentials_enc, :binary, allow_nil?: false, sensitive?: true

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :org, OberCloud.Accounts.Org, allow_nil?: false, public?: true
  end

  validations do
    validate attribute_in(:provider, ~w(hetzner digitalocean vultr))
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:provider, :org_id]
      argument :plaintext_credentials, :map, allow_nil?: false, sensitive?: true

      change fn cs, _ ->
        pt = Ash.Changeset.get_argument(cs, :plaintext_credentials)
        json = Jason.encode!(pt)
        enc = OberCloud.Crypto.encrypt(json)
        Ash.Changeset.force_change_attribute(cs, :credentials_enc, enc)
      end
    end
  end

  def decrypted_credentials(%{credentials_enc: blob}) do
    with {:ok, json} <- OberCloud.Crypto.decrypt(blob),
         {:ok, m} <- Jason.decode(json), do: {:ok, m}
  end
end
