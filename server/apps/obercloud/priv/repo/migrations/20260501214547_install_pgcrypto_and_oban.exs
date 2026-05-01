defmodule OberCloud.Repo.Migrations.InstallPgcryptoAndOban do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto"
    execute "CREATE EXTENSION IF NOT EXISTS citext"
    Oban.Migration.up(version: 12)
  end

  def down do
    Oban.Migration.down(version: 1)
    execute "DROP EXTENSION IF EXISTS citext"
    execute "DROP EXTENSION IF EXISTS pgcrypto"
  end
end
