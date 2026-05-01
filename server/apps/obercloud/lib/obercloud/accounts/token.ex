defmodule OberCloud.Accounts.Token do
  use Ash.Resource,
    otp_app: :obercloud,
    domain: OberCloud.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  postgres do
    table "user_tokens"
    repo OberCloud.Repo
  end
end
