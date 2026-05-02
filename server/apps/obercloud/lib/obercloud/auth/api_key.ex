defmodule OberCloud.Auth.ApiKey do
  use Ash.Resource,
    otp_app: :obercloud,
    domain: OberCloud.Auth,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  require Ash.Query

  @prefix "obk_"
  @random_byte_count 24

  postgres do
    table "api_keys"
    repo OberCloud.Repo
    references do
      reference :org, on_delete: :delete
      reference :user, on_delete: :nilify
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :key_prefix, :string, allow_nil?: false, public?: true
    attribute :key_hash, :string, allow_nil?: false, sensitive?: true
    attribute :role, :string, allow_nil?: false, public?: true

    attribute :expires_at, :utc_datetime, public?: true
    attribute :last_used_at, :utc_datetime, public?: true
    attribute :revoked_at, :utc_datetime, public?: true

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :org, OberCloud.Accounts.Org, allow_nil?: false, public?: true
    belongs_to :user, OberCloud.Accounts.User, public?: true
  end

  validations do
    validate attribute_in(:role, ~w(system:owner org:owner org:admin org:member org:viewer))
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :role, :org_id, :user_id, :expires_at, :key_prefix, :key_hash]
      primary? true
    end

    update :touch_last_used do
      accept []
      change set_attribute(:last_used_at, &DateTime.utc_now/0)
    end

    update :revoke do
      accept []
      change set_attribute(:revoked_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if {OberCloud.Auth.Checks.ActorInOrg, []}
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if {OberCloud.Auth.Checks.ActorHasRole, role: "org:admin"}
    end
  end

  json_api do
    type "api_key"
  end

  # ----- Public helpers -----

  def create_with_plaintext(params) do
    plaintext = generate_plaintext()
    prefix = String.slice(plaintext, 0, 12)
    hash = Bcrypt.hash_pwd_salt(plaintext)

    attrs = params |> Map.put(:key_prefix, prefix) |> Map.put(:key_hash, hash)

    case __MODULE__
         |> Ash.Changeset.for_create(:create, attrs)
         |> Ash.create(authorize?: false) do
      {:ok, key} -> {:ok, %{api_key: key, plaintext: plaintext}}
      err -> err
    end
  end

  def verify(plaintext) when is_binary(plaintext) do
    if String.starts_with?(plaintext, @prefix) do
      prefix = String.slice(plaintext, 0, 12)

      candidates =
        __MODULE__
        |> Ash.Query.new()
        |> Ash.Query.filter(key_prefix == ^prefix and is_nil(revoked_at))
        |> Ash.read!(authorize?: false)

      case Enum.find(candidates, &Bcrypt.verify_pass(plaintext, &1.key_hash)) do
        nil -> {:error, :invalid_key}
        key -> if expired?(key), do: {:error, :expired}, else: {:ok, key}
      end
    else
      {:error, :invalid_key}
    end
  end

  def revoke(key) do
    key |> Ash.Changeset.for_update(:revoke) |> Ash.update(authorize?: false)
  end

  defp generate_plaintext do
    @prefix <> Base.url_encode64(:crypto.strong_rand_bytes(@random_byte_count), padding: false)
  end

  defp expired?(%{expires_at: nil}), do: false
  defp expired?(%{expires_at: at}), do: DateTime.compare(at, DateTime.utc_now()) == :lt
end
