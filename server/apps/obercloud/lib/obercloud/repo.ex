defmodule OberCloud.Repo do
  use Ecto.Repo,
    otp_app: :obercloud,
    adapter: Ecto.Adapters.Postgres
end
