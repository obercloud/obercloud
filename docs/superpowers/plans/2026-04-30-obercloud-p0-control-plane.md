# OberCloud P0 — Control Plane Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the OberCloud control plane: an Elixir/Phoenix application that runs on Hetzner VMs, plus a Rust CLI to bootstrap it and administer it. After P0, users can install OberCloud, log in, manage organizations/users/projects/API keys, and the system is ready for resource provisioning in P1.

**Architecture:** Two-binary system. (1) Elixir/Phoenix umbrella with Ash Framework (resources, RBAC, REST API), Oban (reconciler jobs), libcluster + Horde (3-node coordination), LiveView + LiveVue (UI). (2) Rust CLI (`obercloud`) that bootstraps via OpenTofu and admins the running server via REST. PostgreSQL stores both application data and OpenTofu state.

**Tech Stack:**
- Elixir 1.19 + OTP 28, Phoenix 1.7, Phoenix LiveView 1.0
- Ash Framework 3.x, AshPostgres 2.x, AshAuthentication 4.x, AshJsonApi 1.x
- Oban 2.18, libcluster 3.4, Horde 0.9
- LiveVue 0.5 (Vue 3 components inside LiveView)
- Rust 1.80 (CLI), clap 4, reqwest 0.12, tokio 1
- OpenTofu 1.8, Hetzner Cloud Provider 1.48
- PostgreSQL 16
- License: AGPL-3.0

**Version control note:** Project uses **Jujutsu (jj)**, not git. The user manages commits themselves. At each "Checkpoint — commit" step, the implementer should pause and ask the user to commit via jj — do NOT run any `git` or `jj` commands.

**Project root:** `/home/milad/dev/OberCloud`

---

## File Structure

```
OberCloud/
├── cli/                                    # Rust CLI
│   ├── Cargo.toml
│   ├── Cargo.lock
│   ├── src/
│   │   ├── main.rs
│   │   ├── error.rs
│   │   ├── config.rs
│   │   ├── client.rs
│   │   ├── output.rs
│   │   ├── lib.rs
│   │   └── commands/
│   │       ├── mod.rs
│   │       ├── context.rs
│   │       ├── auth.rs
│   │       ├── orgs.rs
│   │       ├── users.rs
│   │       ├── projects.rs
│   │       ├── nodes.rs
│   │       ├── apikeys.rs
│   │       └── bootstrap/
│   │           ├── mod.rs
│   │           ├── init.rs
│   │           ├── destroy.rs
│   │           ├── upgrade.rs
│   │           ├── tofu.rs
│   │           └── templates/
│   │               ├── single_node.tf
│   │               ├── multi_node.tf
│   │               └── cloud_init.yaml
│   └── tests/
│       ├── config_test.rs
│       ├── client_test.rs
│       └── commands_test.rs
│
├── server/                                 # Elixir umbrella
│   ├── mix.exs
│   ├── config/{config,dev,test,prod,runtime}.exs
│   ├── apps/
│   │   ├── obercloud/                      # Core: business logic, no HTTP
│   │   │   ├── mix.exs
│   │   │   ├── lib/
│   │   │   │   ├── obercloud.ex
│   │   │   │   └── obercloud/
│   │   │   │       ├── application.ex
│   │   │   │       ├── repo.ex
│   │   │   │       ├── crypto.ex
│   │   │   │       ├── accounts.ex
│   │   │   │       ├── accounts/{org,user,token,membership}.ex
│   │   │   │       ├── auth.ex
│   │   │   │       ├── auth/api_key.ex
│   │   │   │       ├── auth/checks/{actor_in_org,actor_has_role}.ex
│   │   │   │       ├── projects.ex
│   │   │   │       ├── projects/project.ex
│   │   │   │       ├── control_plane.ex
│   │   │   │       ├── control_plane/{node,provider_credential}.ex
│   │   │   │       ├── reconciler.ex
│   │   │   │       ├── reconciler/{desired_state,reconcile_worker,drift_detector,hcl_renderer,tofu_runner}.ex
│   │   │   │       └── providers/
│   │   │   │           ├── provider.ex
│   │   │   │           └── hetzner/{client,adapter}.ex
│   │   │   ├── priv/repo/migrations/
│   │   │   └── test/
│   │   │       ├── test_helper.exs
│   │   │       ├── support/data_case.ex
│   │   │       └── obercloud/
│   │   │           ├── accounts_test.exs
│   │   │           ├── auth_test.exs
│   │   │           ├── projects_test.exs
│   │   │           ├── policies_test.exs
│   │   │           ├── control_plane_test.exs
│   │   │           ├── reconciler/{desired_state,reconcile_worker,drift_detector,hcl_renderer,tofu_runner}_test.exs
│   │   │           └── providers/hetzner_test.exs
│   │   │
│   │   └── obercloud_web/                  # Web: Phoenix + LiveView + AshJsonApi
│   │       ├── mix.exs
│   │       ├── assets/
│   │       │   ├── package.json
│   │       │   ├── tsconfig.json
│   │       │   ├── vite.config.ts
│   │       │   ├── vitest.config.ts
│   │       │   ├── js/
│   │       │   │   ├── app.js
│   │       │   │   └── vue/{index.ts,OrgSwitcher.vue,NodeStatusBadge.vue,ApiKeyForm.vue,ResourceTable.vue}
│   │       │   ├── css/app.css
│   │       │   └── test/{OrgSwitcher,NodeStatusBadge,ApiKeyForm,ResourceTable}.test.ts
│   │       ├── lib/
│   │       │   └── obercloud_web/
│   │       │       ├── application.ex
│   │       │       ├── endpoint.ex
│   │       │       ├── router.ex
│   │       │       ├── api_router.ex
│   │       │       ├── live_user_auth.ex
│   │       │       ├── plugs/api_key_plug.ex
│   │       │       ├── controllers/{auth,health}_controller.ex
│   │       │       ├── live/{dashboard,orgs,projects,nodes,api_keys,users}_live.ex
│   │       │       └── components/{core_components,layouts}.ex
│   │       └── test/
│   │           ├── support/conn_case.ex
│   │           └── obercloud_web/
│   │               ├── live/{login,dashboard,orgs,nodes}_live_test.exs
│   │               ├── plugs/api_key_plug_test.exs
│   │               └── api/{orgs,projects,api_keys}_test.exs
│
├── .github/workflows/ci.yml
├── LICENSE                                 # AGPL-3.0
├── README.md
├── .gitignore
└── docs/                                   # Already exists
```

---

## Phase 1: Project Scaffolding

### Task 1: Repository skeleton (license, README, .gitignore)

**Files:**
- Create: `LICENSE`, `README.md`, `.gitignore` at project root

- [ ] **Step 1: Add the AGPL-3.0 license file**

Download the official AGPL-3.0 text from https://www.gnu.org/licenses/agpl-3.0.txt and save it verbatim to `LICENSE`. Add a copyright header at the top:

```
Copyright (C) 2026 OberCloud Contributors

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published
by the Free Software Foundation, version 3.

[Full AGPL-3.0 text follows below]
```

- [ ] **Step 2: Create the README**

Write `README.md`:

```markdown
# OberCloud

Open-source platform for managed infrastructure on commodity cloud providers (Hetzner, DigitalOcean, ...).

**Status:** Pre-alpha — P0 in development.

## What it is

OberCloud lets indie developers and small companies self-host a Fly.io / Heroku-style platform on cheap VMs. After installation:

- Multi-tenant from day one (organizations isolate workloads per customer)
- Web UI + REST API + Rust CLI for management
- AGPL-3.0 licensed; commercial enterprise license available

## Repository layout

- `server/` — Elixir/Phoenix umbrella (control plane application)
- `cli/` — Rust CLI (`obercloud` binary)
- `docs/` — Specs and implementation plans

## License

AGPL-3.0. See [LICENSE](LICENSE).
```

- [ ] **Step 3: Create root `.gitignore`**

```
# Elixir
server/_build/
server/deps/
server/cover/
server/.elixir_ls/
server/erl_crash.dump
server/*.ez
server/*.beam
server/.fetch
server/priv/static/assets/
server/apps/*/priv/static/assets/

# Node
server/apps/obercloud_web/assets/node_modules/
server/apps/obercloud_web/assets/dist/

# Rust
cli/target/

# OS / Editor
.DS_Store
.vscode/
.idea/
*.swp

# Local config
.env
.env.local
```

- [ ] **Step 4: Checkpoint — pause for jj commit**

---

### Task 2: Elixir umbrella scaffold

**Files:** the entire `server/` directory generated by `mix phx.new`.

- [ ] **Step 1: Verify Elixir/OTP**

```bash
elixir --version
```

Expected: `Elixir 1.19.x` on `Erlang/OTP 28`. The `.tool-versions` file at the project root pins these via mise/asdf.

- [ ] **Step 2: Generate the Phoenix umbrella**

```bash
cd /home/milad/dev/OberCloud
mix phx.new server --umbrella --database postgres --module OberCloud --app obercloud
```

Press `Y` when prompted to fetch dependencies. Creates `server/apps/obercloud` and `server/apps/obercloud_web`.

- [ ] **Step 3: Verify it boots**

```bash
cd server
mix ecto.create
mix test
```

Expected: All generated tests pass (`X tests, 0 failures`).

- [ ] **Step 4: Checkpoint — commit via jj**

---

### Task 3: Add core dependencies

**Files:**
- Modify: `server/apps/obercloud/mix.exs`
- Modify: `server/apps/obercloud_web/mix.exs`
- Modify: `server/config/config.exs`

- [ ] **Step 1: Replace `deps` in `server/apps/obercloud/mix.exs`**

```elixir
defp deps do
  [
    {:phoenix_pubsub, "~> 2.1"},
    {:ecto_sql, "~> 3.12"},
    {:postgrex, "~> 0.19"},
    {:jason, "~> 1.4"},

    # Ash framework
    {:ash, "~> 3.4"},
    {:ash_postgres, "~> 2.4"},
    {:ash_authentication, "~> 4.4"},
    {:ash_authentication_phoenix, "~> 2.4"},
    {:ash_json_api, "~> 1.4"},

    # Background jobs
    {:oban, "~> 2.18"},

    # Distributed Erlang
    {:libcluster, "~> 3.4"},
    {:horde, "~> 0.9"},

    # HTTP client
    {:req, "~> 0.5"},

    # Crypto
    {:bcrypt_elixir, "~> 3.1"},

    # Test
    {:bypass, "~> 2.1", only: :test},
    {:mox, "~> 1.2", only: :test}
  ]
end
```

Also update the `project` function:

```elixir
def project do
  [
    app: :obercloud,
    version: "0.1.0",
    build_path: "../../_build",
    config_path: "../../config/config.exs",
    deps_path: "../../deps",
    lockfile: "../../mix.lock",
    elixir: "~> 1.19",
    elixirc_paths: elixirc_paths(Mix.env()),
    start_permanent: Mix.env() == :prod,
    aliases: aliases(),
    deps: deps()
  ]
end

defp elixirc_paths(:test), do: ["lib", "test/support"]
defp elixirc_paths(_), do: ["lib"]
```

- [ ] **Step 2: Add web deps to `server/apps/obercloud_web/mix.exs`**

Add to the existing `deps`:

```elixir
{:ash_phoenix, "~> 2.1"},
{:ash_authentication_phoenix, "~> 2.4"},
{:ash_json_api, "~> 1.4"},
{:live_vue, "~> 0.5"},
{:floki, ">= 0.30.0", only: :test}
```

Also add `elixirc_paths(:test), do: ["lib", "test/support"]` (same pattern as core).

- [ ] **Step 3: Configure Ash domains in `server/config/config.exs`**

Add at the bottom (before any `import_config`):

```elixir
config :obercloud,
  ash_domains: [
    OberCloud.Accounts,
    OberCloud.Auth,
    OberCloud.Projects,
    OberCloud.ControlPlane,
    OberCloud.Reconciler
  ]

config :ash, :include_embedded_source_by_default?, false
config :ash, :default_belongs_to_type, :uuid

config :spark, :formatter, remove_parens?: true
```

- [ ] **Step 4: Fetch deps & verify compile**

```bash
cd /home/milad/dev/OberCloud/server
mix deps.get
mix compile
```

Expected: compiles. Warnings about empty domains are OK — domain modules don't exist yet.

- [ ] **Step 5: Checkpoint — commit via jj**

---

### Task 4: Rust CLI scaffold

**Files:** `cli/Cargo.toml`, `cli/src/{main,lib,error,output,config,client}.rs`, `cli/src/commands/{mod,context,auth,orgs,users,projects,nodes,apikeys}.rs`, `cli/src/commands/bootstrap/{mod,init,destroy,upgrade}.rs`

- [ ] **Step 1: Initialize**

```bash
cd /home/milad/dev/OberCloud
cargo new cli --bin --name obercloud
```

- [ ] **Step 2: Replace `cli/Cargo.toml`**

```toml
[package]
name = "obercloud"
version = "0.1.0"
edition = "2021"
license = "AGPL-3.0"
description = "OberCloud control plane CLI"

[[bin]]
name = "obercloud"
path = "src/main.rs"

[lib]
path = "src/lib.rs"

[dependencies]
clap = { version = "4.5", features = ["derive"] }
tokio = { version = "1.40", features = ["full"] }
reqwest = { version = "0.12", features = ["json", "rustls-tls"], default-features = false }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
toml = "0.8"
dirs = "5.0"
dialoguer = "0.11"
indicatif = "0.17"
colored = "2.1"
thiserror = "1.0"
anyhow = "1.0"
tempfile = "3.13"
chrono = { version = "0.4", features = ["serde"] }

[dev-dependencies]
mockito = "1.5"
assert_cmd = "2.0"
predicates = "3.1"
```

- [ ] **Step 3: Create `cli/src/error.rs`**

```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum CliError {
    #[error("config error: {0}")]
    Config(String),
    #[error("no active context — run `obercloud context use <name>` first")]
    NoActiveContext,
    #[error("HTTP error: {0}")]
    Http(#[from] reqwest::Error),
    #[error("API error ({status}): {message}")]
    Api { status: u16, message: String },
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("TOML parse error: {0}")]
    TomlDe(#[from] toml::de::Error),
    #[error("TOML serialize error: {0}")]
    TomlSer(#[from] toml::ser::Error),
    #[error("OpenTofu error: {0}")]
    Tofu(String),
    #[error("validation error: {0}")]
    Validation(String),
}

pub type Result<T> = std::result::Result<T, CliError>;
```

- [ ] **Step 4: Create `cli/src/lib.rs`**

```rust
pub mod commands;
pub mod config;
pub mod client;
pub mod error;
pub mod output;

pub use error::{CliError, Result};
```

- [ ] **Step 5: Create `cli/src/output.rs`**

```rust
use colored::Colorize;

pub fn success(msg: &str) {
    println!("{} {}", "✓".green(), msg);
}

pub fn error(msg: &str) {
    eprintln!("{} {}", "✗".red(), msg);
}

pub fn info(msg: &str) {
    println!("{} {}", "→".cyan(), msg);
}
```

- [ ] **Step 6: Create stub modules**

`cli/src/config.rs`:
```rust
// Implemented in Task 27
```

`cli/src/client.rs`:
```rust
// Implemented in Task 28
```

`cli/src/commands/mod.rs`:
```rust
pub mod context;
pub mod auth;
pub mod orgs;
pub mod users;
pub mod projects;
pub mod nodes;
pub mod apikeys;
pub mod bootstrap;
```

For each of `context.rs`, `auth.rs`, `orgs.rs`, `users.rs`, `projects.rs`, `nodes.rs`, `apikeys.rs`, create the same shape with appropriate enum names (`ContextCommand`, `AuthCommand`, etc.):

```rust
// cli/src/commands/context.rs
use clap::Subcommand;
use crate::Result;

#[derive(Subcommand)]
pub enum ContextCommand {
    #[command(hide = true)]
    Stub,
}

pub async fn run(_cmd: ContextCommand) -> Result<()> {
    todo!("implemented in Task 29+")
}
```

`cli/src/commands/bootstrap/mod.rs`:
```rust
pub mod init;
pub mod destroy;
pub mod upgrade;
```

`cli/src/commands/bootstrap/init.rs`, `destroy.rs`, `upgrade.rs`:
```rust
use clap::Args as ClapArgs;
use crate::Result;

#[derive(ClapArgs)]
pub struct Args {}

pub async fn run(_args: Args) -> Result<()> {
    todo!("implemented in Task 31")
}
```

- [ ] **Step 7: Replace `cli/src/main.rs`**

```rust
use clap::{Parser, Subcommand};
use obercloud::commands;
use obercloud::Result;

#[derive(Parser)]
#[command(name = "obercloud", version, about = "OberCloud control plane CLI")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Bootstrap a new OberCloud installation
    Init(commands::bootstrap::init::Args),
    /// Tear down an OberCloud installation
    Destroy(commands::bootstrap::destroy::Args),
    /// Upgrade an existing OberCloud installation
    Upgrade(commands::bootstrap::upgrade::Args),
    #[command(subcommand)]
    Context(commands::context::ContextCommand),
    #[command(subcommand)]
    Auth(commands::auth::AuthCommand),
    #[command(subcommand)]
    Orgs(commands::orgs::OrgsCommand),
    #[command(subcommand)]
    Users(commands::users::UsersCommand),
    #[command(subcommand)]
    Projects(commands::projects::ProjectsCommand),
    #[command(subcommand)]
    Nodes(commands::nodes::NodesCommand),
    #[command(subcommand)]
    Apikeys(commands::apikeys::ApikeysCommand),
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();
    match cli.command {
        Command::Init(a) => commands::bootstrap::init::run(a).await,
        Command::Destroy(a) => commands::bootstrap::destroy::run(a).await,
        Command::Upgrade(a) => commands::bootstrap::upgrade::run(a).await,
        Command::Context(c) => commands::context::run(c).await,
        Command::Auth(c) => commands::auth::run(c).await,
        Command::Orgs(c) => commands::orgs::run(c).await,
        Command::Users(c) => commands::users::run(c).await,
        Command::Projects(c) => commands::projects::run(c).await,
        Command::Nodes(c) => commands::nodes::run(c).await,
        Command::Apikeys(c) => commands::apikeys::run(c).await,
    }
}
```

- [ ] **Step 8: Verify compile + help**

```bash
cd /home/milad/dev/OberCloud/cli
cargo build
./target/debug/obercloud --help
```

Expected: shows top-level subcommands.

- [ ] **Step 9: Checkpoint — commit via jj**

---

## Phase 2: Data Model (Ash Resources + Migrations)

### Task 5: Bootstrap migration (pgcrypto, citext, Oban tables)

**Files:** `server/apps/obercloud/priv/repo/migrations/<timestamp>_install_pgcrypto_and_oban.exs`

- [ ] **Step 1: Generate**

```bash
cd /home/milad/dev/OberCloud/server
mix ecto.gen.migration install_pgcrypto_and_oban
```

- [ ] **Step 2: Replace generated content**

```elixir
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
```

- [ ] **Step 3: Run migration**

```bash
mix ecto.migrate
```

Expected: extensions installed, Oban tables created.

- [ ] **Step 4: Checkpoint — commit**

---

### Task 6: DataCase + Org Ash resource

**Files:**
- Create: `server/apps/obercloud/test/support/data_case.ex`
- Create: `server/apps/obercloud/lib/obercloud/accounts.ex`
- Create: `server/apps/obercloud/lib/obercloud/accounts/org.ex`
- Create: `server/apps/obercloud/test/obercloud/accounts_test.exs`

- [ ] **Step 1: DataCase**

`server/apps/obercloud/test/support/data_case.ex`:
```elixir
defmodule OberCloud.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias OberCloud.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import OberCloud.DataCase
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(OberCloud.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end
```

- [ ] **Step 2: Failing test**

`server/apps/obercloud/test/obercloud/accounts_test.exs`:

```elixir
defmodule OberCloud.AccountsTest do
  use OberCloud.DataCase, async: true
  alias OberCloud.Accounts.Org

  describe "organizations" do
    test "creates an organization" do
      assert {:ok, org} =
               Org
               |> Ash.Changeset.for_create(:create, %{name: "Acme Corp", slug: "acme"})
               |> Ash.create()

      assert org.name == "Acme Corp"
      assert org.slug == "acme"
    end

    test "rejects duplicate slug" do
      params = %{name: "Acme", slug: "acme"}
      {:ok, _} = Ash.create(Org, params)
      assert {:error, _} = Ash.create(Org, params)
    end

    test "rejects invalid slug format" do
      assert {:error, _} = Ash.create(Org, %{name: "Acme", slug: "Has Spaces!"})
    end
  end
end
```

- [ ] **Step 3: Verify test fails**

```bash
mix test apps/obercloud/test/obercloud/accounts_test.exs
```

Expected: FAIL with `OberCloud.Accounts.Org is not loaded`.

- [ ] **Step 4: Create the Accounts domain**

`server/apps/obercloud/lib/obercloud/accounts.ex`:
```elixir
defmodule OberCloud.Accounts do
  use Ash.Domain, otp_app: :obercloud, extensions: [AshJsonApi.Domain]

  resources do
    resource OberCloud.Accounts.Org
  end

  json_api do
    routes do
      base_route "/orgs", OberCloud.Accounts.Org do
        get :read
        index :read
        post :create
        patch :update
        delete :destroy
      end
    end
  end
end
```

- [ ] **Step 5: Create the Org resource**

`server/apps/obercloud/lib/obercloud/accounts/org.ex`:
```elixir
defmodule OberCloud.Accounts.Org do
  use Ash.Resource,
    otp_app: :obercloud,
    domain: OberCloud.Accounts,
    data_layer: AshPostgres.DataLayer,
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

  json_api do
    type "org"
  end
end
```

- [ ] **Step 6: Generate + run Ash migration**

```bash
mix ash_postgres.generate_migrations --name create_orgs
mix ecto.migrate
```

- [ ] **Step 7: Run tests**

```bash
mix test apps/obercloud/test/obercloud/accounts_test.exs
```

Expected: 3 tests pass.

- [ ] **Step 8: Checkpoint — commit**

---

### Task 7: User + Token resources (AshAuthentication)

**Files:**
- Modify: `server/config/runtime.exs`
- Modify: `server/apps/obercloud/lib/obercloud/accounts.ex`
- Create: `server/apps/obercloud/lib/obercloud/accounts/user.ex`
- Create: `server/apps/obercloud/lib/obercloud/accounts/token.ex`
- Modify: `server/apps/obercloud/test/obercloud/accounts_test.exs`

- [ ] **Step 1: Add token signing secret to runtime config**

`server/config/runtime.exs`, top-level (outside `if config_env() == :prod`):

```elixir
config :obercloud, :token_signing_secret,
  System.get_env("TOKEN_SIGNING_SECRET") ||
    "dev-only-secret-replace-in-prod-min-32-bytes-long-string!"
```

- [ ] **Step 2: Append failing test**

Append to `accounts_test.exs`:

```elixir
describe "users" do
  test "registers a user with email and password" do
    {:ok, user} =
      OberCloud.Accounts.User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "alice@example.com",
        name: "Alice",
        password: "supersecret123",
        password_confirmation: "supersecret123"
      })
      |> Ash.create()

    assert "#{user.email}" == "alice@example.com"
    refute user.hashed_password == "supersecret123"
  end

  test "rejects mismatched password confirmation" do
    assert {:error, _} =
             OberCloud.Accounts.User
             |> Ash.Changeset.for_create(:register_with_password, %{
               email: "bob@example.com",
               name: "Bob",
               password: "secret123456",
               password_confirmation: "different12345"
             })
             |> Ash.create()
  end

  test "signs in with valid credentials" do
    {:ok, _} =
      OberCloud.Accounts.User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "carol@example.com",
        name: "Carol",
        password: "supersecret123",
        password_confirmation: "supersecret123"
      })
      |> Ash.create()

    assert {:ok, [user]} =
             OberCloud.Accounts.User
             |> Ash.Query.for_read(:sign_in_with_password, %{
               email: "carol@example.com",
               password: "supersecret123"
             })
             |> Ash.read()

    assert "#{user.email}" == "carol@example.com"
  end
end
```

- [ ] **Step 3: Token resource**

`server/apps/obercloud/lib/obercloud/accounts/token.ex`:
```elixir
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
```

- [ ] **Step 4: User resource**

`server/apps/obercloud/lib/obercloud/accounts/user.ex`:
```elixir
defmodule OberCloud.Accounts.User do
  use Ash.Resource,
    otp_app: :obercloud,
    domain: OberCloud.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication]

  postgres do
    table "users"
    repo OberCloud.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string, allow_nil?: false, public?: true

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :hashed_password, :string, allow_nil?: false, sensitive?: true

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_email, [:email]
  end

  authentication do
    tokens do
      enabled? true
      token_resource OberCloud.Accounts.Token
      signing_secret fn _, _ ->
        {:ok, Application.fetch_env!(:obercloud, :token_signing_secret)}
      end
    end

    strategies do
      password :password do
        identity_field :email
        hashed_password_field :hashed_password
        confirmation_required? true
        register_action_accept [:name]
      end
    end
  end

  actions do
    defaults [:read]
  end
end
```

- [ ] **Step 5: Register in domain**

```elixir
resources do
  resource OberCloud.Accounts.Org
  resource OberCloud.Accounts.User
  resource OberCloud.Accounts.Token
end
```

- [ ] **Step 6: Migrate + test**

```bash
mix ash_postgres.generate_migrations --name create_users_and_tokens
mix ecto.migrate
mix test apps/obercloud/test/obercloud/accounts_test.exs
```

Expected: 6 tests pass.

- [ ] **Step 7: Checkpoint — commit**

---

### Task 8: Membership resource

**Files:**
- Create: `server/apps/obercloud/lib/obercloud/accounts/membership.ex`
- Modify: `accounts.ex`, `user.ex`, `org.ex`, `accounts_test.exs`

- [ ] **Step 1: Append failing tests**

Append to `accounts_test.exs`:

```elixir
describe "memberships" do
  setup do
    {:ok, org} = Ash.create(OberCloud.Accounts.Org, %{name: "Acme", slug: "acme"})
    {:ok, user} =
      OberCloud.Accounts.User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "dan@example.com", name: "Dan",
        password: "secret123456", password_confirmation: "secret123456"
      })
      |> Ash.create()
    {:ok, org: org, user: user}
  end

  test "creates a membership with a role", %{org: org, user: user} do
    assert {:ok, m} =
             OberCloud.Accounts.Membership
             |> Ash.Changeset.for_create(:create, %{
               org_id: org.id, user_id: user.id, role: "org:owner"
             })
             |> Ash.create()
    assert m.role == "org:owner"
  end

  test "rejects invalid role", %{org: org, user: user} do
    assert {:error, _} =
             OberCloud.Accounts.Membership
             |> Ash.Changeset.for_create(:create, %{
               org_id: org.id, user_id: user.id, role: "invalid"
             })
             |> Ash.create()
  end

  test "rejects duplicate user/org pair", %{org: org, user: user} do
    p = %{org_id: org.id, user_id: user.id, role: "org:member"}
    {:ok, _} = Ash.create(OberCloud.Accounts.Membership, p)
    assert {:error, _} = Ash.create(OberCloud.Accounts.Membership, p)
  end
end
```

- [ ] **Step 2: Membership resource**

`server/apps/obercloud/lib/obercloud/accounts/membership.ex`:
```elixir
defmodule OberCloud.Accounts.Membership do
  use Ash.Resource,
    otp_app: :obercloud,
    domain: OberCloud.Accounts,
    data_layer: AshPostgres.DataLayer

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
      constraints one_of: ~w(system:owner org:owner org:admin org:member org:viewer)
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
```

- [ ] **Step 3: Register + add `has_many` on User and Org**

`accounts.ex`:
```elixir
resources do
  resource OberCloud.Accounts.Org
  resource OberCloud.Accounts.User
  resource OberCloud.Accounts.Token
  resource OberCloud.Accounts.Membership
end
```

Add `relationships do has_many :memberships, OberCloud.Accounts.Membership end` to both `user.ex` and `org.ex`.

- [ ] **Step 4: Migrate + test**

```bash
mix ash_postgres.generate_migrations --name create_memberships
mix ecto.migrate
mix test apps/obercloud/test/obercloud/accounts_test.exs
```

Expected: 9 tests pass.

- [ ] **Step 5: Checkpoint — commit**

---

### Task 9: Project resource

**Files:**
- Create: `server/apps/obercloud/lib/obercloud/projects.ex`
- Create: `server/apps/obercloud/lib/obercloud/projects/project.ex`
- Create: `server/apps/obercloud/test/obercloud/projects_test.exs`

- [ ] **Step 1: Failing test**

```elixir
defmodule OberCloud.ProjectsTest do
  use OberCloud.DataCase, async: true
  alias OberCloud.Projects.Project

  setup do
    {:ok, org} = Ash.create(OberCloud.Accounts.Org, %{name: "Acme", slug: "acme"})
    {:ok, org: org}
  end

  test "creates a project", %{org: org} do
    assert {:ok, p} =
             Project
             |> Ash.Changeset.for_create(:create, %{
               name: "Production", slug: "production", org_id: org.id
             })
             |> Ash.create()
    assert p.slug == "production"
  end

  test "enforces slug uniqueness within an org", %{org: org} do
    params = %{name: "Production", slug: "production", org_id: org.id}
    {:ok, _} = Ash.create(Project, params)
    assert {:error, _} = Ash.create(Project, params)
  end

  test "allows same slug across different orgs", %{org: org} do
    {:ok, org2} = Ash.create(OberCloud.Accounts.Org, %{name: "Other", slug: "other"})
    {:ok, _} = Ash.create(Project, %{name: "Prod", slug: "prod", org_id: org.id})
    assert {:ok, _} = Ash.create(Project, %{name: "Prod", slug: "prod", org_id: org2.id})
  end
end
```

- [ ] **Step 2: Domain + resource**

`projects.ex`:
```elixir
defmodule OberCloud.Projects do
  use Ash.Domain, otp_app: :obercloud, extensions: [AshJsonApi.Domain]

  resources do
    resource OberCloud.Projects.Project
  end

  json_api do
    routes do
      base_route "/projects", OberCloud.Projects.Project do
        get :read
        index :read
        post :create
        patch :update
        delete :destroy
      end
    end
  end
end
```

`projects/project.ex`:
```elixir
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
```

- [ ] **Step 3: Migrate, test, commit**

```bash
mix ash_postgres.generate_migrations --name create_projects
mix ecto.migrate
mix test apps/obercloud/test/obercloud/projects_test.exs
```

Expected: 3 tests pass.

---

### Task 10: ControlPlane domain (Node + ProviderCredential + Crypto)

**Files:**
- Create: `server/apps/obercloud/lib/obercloud/crypto.ex`
- Create: `server/apps/obercloud/lib/obercloud/control_plane.ex`
- Create: `server/apps/obercloud/lib/obercloud/control_plane/node.ex`
- Create: `server/apps/obercloud/lib/obercloud/control_plane/provider_credential.ex`
- Create: `server/apps/obercloud/test/obercloud/control_plane_test.exs`
- Modify: `server/config/runtime.exs`

- [ ] **Step 1: Encryption key config**

In `runtime.exs`:
```elixir
config :obercloud, :credential_encryption_key,
  case System.get_env("CREDENTIAL_ENCRYPTION_KEY") do
    nil -> Base.decode64!("ZGV2X2tleV8zMl9ieXRlc19sb25nX2Rldl9rZXkhX2Z2YQ==")
    val -> Base.decode64!(val)
  end
```

- [ ] **Step 2: Crypto helper**

`crypto.ex`:
```elixir
defmodule OberCloud.Crypto do
  @aad "obercloud:provider_credential:v1"

  def encrypt(plaintext) when is_binary(plaintext) do
    key = key()
    iv = :crypto.strong_rand_bytes(12)
    {ct, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, @aad, true)
    iv <> tag <> ct
  end

  def decrypt(<<iv::binary-size(12), tag::binary-size(16), ct::binary>>) do
    key = key()
    case :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ct, @aad, tag, false) do
      :error -> {:error, :decryption_failed}
      pt -> {:ok, pt}
    end
  end

  defp key, do: Application.fetch_env!(:obercloud, :credential_encryption_key)
end
```

- [ ] **Step 3: Failing test**

`control_plane_test.exs`:
```elixir
defmodule OberCloud.ControlPlaneTest do
  use OberCloud.DataCase, async: true
  alias OberCloud.ControlPlane.{Node, ProviderCredential}

  setup do
    {:ok, org} = Ash.create(OberCloud.Accounts.Org, %{name: "Acme", slug: "acme"})
    {:ok, org: org}
  end

  describe "nodes" do
    test "creates a node in provisioning state" do
      assert {:ok, node} =
               Node
               |> Ash.Changeset.for_create(:create, %{
                 provider: "hetzner",
                 role: "primary",
                 status: "provisioning",
                 provider_metadata: %{"region" => "nbg1", "server_type" => "cx21"}
               })
               |> Ash.create()
      assert node.status == "provisioning"
    end

    test "rejects invalid provider" do
      assert {:error, _} =
               Node
               |> Ash.Changeset.for_create(:create, %{provider: "aws", role: "primary", status: "provisioning"})
               |> Ash.create()
    end

    test "rejects invalid status" do
      assert {:error, _} =
               Node
               |> Ash.Changeset.for_create(:create, %{provider: "hetzner", role: "primary", status: "wat"})
               |> Ash.create()
    end
  end

  describe "provider credentials" do
    test "stores encrypted credentials and decrypts back", %{org: org} do
      assert {:ok, cred} =
               ProviderCredential
               |> Ash.Changeset.for_create(:create, %{
                 org_id: org.id, provider: "hetzner",
                 plaintext_credentials: %{"api_token" => "test-token-12345"}
               })
               |> Ash.create()

      reloaded = Ash.get!(ProviderCredential, cred.id)
      assert {:ok, %{"api_token" => "test-token-12345"}} =
               ProviderCredential.decrypted_credentials(reloaded)
      refute reloaded.credentials_enc =~ "test-token-12345"
    end
  end
end
```

- [ ] **Step 4: Domain**

`control_plane.ex`:
```elixir
defmodule OberCloud.ControlPlane do
  use Ash.Domain, otp_app: :obercloud, extensions: [AshJsonApi.Domain]

  resources do
    resource OberCloud.ControlPlane.Node
    resource OberCloud.ControlPlane.ProviderCredential
  end

  json_api do
    routes do
      base_route "/nodes", OberCloud.ControlPlane.Node do
        get :read
        index :read
      end
    end
  end
end
```

- [ ] **Step 5: Node resource**

`control_plane/node.ex`:
```elixir
defmodule OberCloud.ControlPlane.Node do
  use Ash.Resource,
    otp_app: :obercloud,
    domain: OberCloud.ControlPlane,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    table "nodes"
    repo OberCloud.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :provider, :string do
      allow_nil? false
      public? true
      constraints one_of: ~w(hetzner digitalocean)
    end

    attribute :provider_resource_id, :string, public?: true
    attribute :provider_metadata, :map, default: %{}, public?: true
    attribute :ip_address, :string, public?: true

    attribute :role, :string do
      allow_nil? false
      public? true
      constraints one_of: ~w(primary standby worker)
    end

    attribute :status, :string do
      allow_nil? false
      public? true
      constraints one_of: ~w(provisioning ready degraded decommissioned)
    end

    attribute :joined_at, :utc_datetime, public?: true

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:provider, :provider_resource_id, :provider_metadata,
              :ip_address, :role, :status]
      primary? true
    end

    update :update do
      accept [:provider_resource_id, :provider_metadata, :ip_address, :status, :joined_at]
      primary? true
    end

    update :mark_ready do
      accept [:ip_address, :provider_resource_id]
      change set_attribute(:status, "ready")
      change set_attribute(:joined_at, &DateTime.utc_now/0)
    end
  end

  json_api do
    type "node"
  end
end
```

- [ ] **Step 6: ProviderCredential resource**

`control_plane/provider_credential.ex`:
```elixir
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

    attribute :provider, :string do
      allow_nil? false
      public? true
      constraints one_of: ~w(hetzner digitalocean)
    end

    attribute :credentials_enc, :binary, allow_nil?: false, sensitive?: true

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :org, OberCloud.Accounts.Org, allow_nil?: false, public?: true
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

  def decrypted_credentials(%__MODULE__{credentials_enc: blob}) do
    with {:ok, json} <- OberCloud.Crypto.decrypt(blob),
         {:ok, m} <- Jason.decode(json), do: {:ok, m}
  end
end
```

- [ ] **Step 7: Migrate + test**

```bash
mix ash_postgres.generate_migrations --name create_nodes_and_provider_credentials
mix ecto.migrate
mix test apps/obercloud/test/obercloud/control_plane_test.exs
```

Expected: 4 tests pass.

- [ ] **Step 8: Checkpoint — commit**

---

### Task 11: API Key resource

**Files:**
- Create: `server/apps/obercloud/lib/obercloud/auth.ex`
- Create: `server/apps/obercloud/lib/obercloud/auth/api_key.ex`
- Create: `server/apps/obercloud/test/obercloud/auth_test.exs`

- [ ] **Step 1: Failing test**

```elixir
defmodule OberCloud.AuthTest do
  use OberCloud.DataCase, async: true
  alias OberCloud.Auth.ApiKey

  setup do
    {:ok, org} = Ash.create(OberCloud.Accounts.Org, %{name: "Acme", slug: "acme"})
    {:ok, org: org}
  end

  test "creates a key and returns the plaintext exactly once", %{org: org} do
    assert {:ok, %{api_key: key, plaintext: pt}} =
             ApiKey.create_with_plaintext(%{name: "CI", org_id: org.id, role: "org:admin"})
    assert String.starts_with?(pt, "obk_")
    refute key.key_hash == pt
  end

  test "verifies a valid key", %{org: org} do
    {:ok, %{plaintext: pt}} =
      ApiKey.create_with_plaintext(%{name: "k", org_id: org.id, role: "org:admin"})
    assert {:ok, _} = ApiKey.verify(pt)
  end

  test "rejects an invalid key" do
    assert {:error, :invalid_key} = ApiKey.verify("obk_garbage_value_xxx")
  end

  test "rejects a revoked key", %{org: org} do
    {:ok, %{api_key: k, plaintext: pt}} =
      ApiKey.create_with_plaintext(%{name: "k", org_id: org.id, role: "org:admin"})
    {:ok, _} = ApiKey.revoke(k)
    assert {:error, :invalid_key} = ApiKey.verify(pt)
  end
end
```

- [ ] **Step 2: Domain**

`auth.ex`:
```elixir
defmodule OberCloud.Auth do
  use Ash.Domain, otp_app: :obercloud, extensions: [AshJsonApi.Domain]

  resources do
    resource OberCloud.Auth.ApiKey
  end

  json_api do
    routes do
      base_route "/api_keys", OberCloud.Auth.ApiKey do
        get :read
        index :read
        post :create
        delete :destroy
      end
    end
  end
end
```

- [ ] **Step 3: ApiKey resource**

`auth/api_key.ex`:
```elixir
defmodule OberCloud.Auth.ApiKey do
  use Ash.Resource,
    otp_app: :obercloud,
    domain: OberCloud.Auth,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

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

    attribute :role, :string do
      allow_nil? false
      public? true
      constraints one_of: ~w(system:owner org:owner org:admin org:member org:viewer)
    end

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

  json_api do
    type "api_key"
  end

  def create_with_plaintext(params) do
    plaintext = generate_plaintext()
    prefix = String.slice(plaintext, 0, 12)
    hash = Bcrypt.hash_pwd_salt(plaintext)

    attrs = params |> Map.put(:key_prefix, prefix) |> Map.put(:key_hash, hash)

    case __MODULE__
         |> Ash.Changeset.for_create(:create, attrs)
         |> Ash.create() do
      {:ok, key} -> {:ok, %{api_key: key, plaintext: plaintext}}
      err -> err
    end
  end

  def verify(plaintext) when is_binary(plaintext) do
    if String.starts_with?(plaintext, @prefix) do
      prefix = String.slice(plaintext, 0, 12)

      candidates =
        __MODULE__
        |> Ash.Query.filter(key_prefix == ^prefix and is_nil(revoked_at))
        |> Ash.read!()

      case Enum.find(candidates, &Bcrypt.verify_pass(plaintext, &1.key_hash)) do
        nil -> {:error, :invalid_key}
        key -> if expired?(key), do: {:error, :expired}, else: {:ok, key}
      end
    else
      {:error, :invalid_key}
    end
  end

  def revoke(%__MODULE__{} = key) do
    key |> Ash.Changeset.for_update(:revoke) |> Ash.update()
  end

  defp generate_plaintext do
    @prefix <> Base.url_encode64(:crypto.strong_rand_bytes(@random_byte_count), padding: false)
  end

  defp expired?(%{expires_at: nil}), do: false
  defp expired?(%{expires_at: at}), do: DateTime.compare(at, DateTime.utc_now()) == :lt
end
```

- [ ] **Step 4: Migrate + test**

```bash
mix ash_postgres.generate_migrations --name create_api_keys
mix ecto.migrate
mix test apps/obercloud/test/obercloud/auth_test.exs
```

Expected: 4 tests pass.

- [ ] **Step 5: Checkpoint — commit**

---

### Task 12: Reconciler domain (DesiredState resource)

**Files:**
- Create: `server/apps/obercloud/lib/obercloud/reconciler.ex`
- Create: `server/apps/obercloud/lib/obercloud/reconciler/desired_state.ex`
- Create: `server/apps/obercloud/test/obercloud/reconciler/desired_state_test.exs`

- [ ] **Step 1: Failing test**

```elixir
defmodule OberCloud.Reconciler.DesiredStateTest do
  use OberCloud.DataCase, async: true
  alias OberCloud.Reconciler.DesiredState

  setup do
    {:ok, org} = Ash.create(OberCloud.Accounts.Org, %{name: "Acme", slug: "acme"})
    {:ok, org: org}
  end

  test "creates pending desired_state row", %{org: org} do
    {:ok, ds} =
      DesiredState
      |> Ash.Changeset.for_create(:create, %{
        org_id: org.id,
        resource_type: "node",
        resource_id: Ecto.UUID.generate(),
        spec: %{"region" => "nbg1"}
      })
      |> Ash.create()
    assert ds.reconcile_status == "pending"
  end

  test "transitions to ready", %{org: org} do
    {:ok, ds} =
      DesiredState
      |> Ash.Changeset.for_create(:create, %{
        org_id: org.id, resource_type: "node",
        resource_id: Ecto.UUID.generate(), spec: %{}
      })
      |> Ash.create()
    {:ok, ready} = ds |> Ash.Changeset.for_update(:mark_ready) |> Ash.update()
    assert ready.reconcile_status == "ready"
    assert ready.reconciled_at
  end
end
```

- [ ] **Step 2: Domain + resource**

`reconciler.ex`:
```elixir
defmodule OberCloud.Reconciler do
  use Ash.Domain, otp_app: :obercloud

  resources do
    resource OberCloud.Reconciler.DesiredState
  end
end
```

`reconciler/desired_state.ex`:
```elixir
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
      constraints one_of: ~w(pending reconciling ready failed drifted)
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
```

- [ ] **Step 3: Migrate, test, commit**

```bash
mix ash_postgres.generate_migrations --name create_desired_state
mix ecto.migrate
mix test apps/obercloud/test/obercloud/reconciler/desired_state_test.exs
```

Expected: 2 tests pass.

---

## Phase 3: RBAC Policies

### Task 13: Custom Ash policy checks

**Files:**
- Create: `server/apps/obercloud/lib/obercloud/auth/checks/actor_in_org.ex`
- Create: `server/apps/obercloud/lib/obercloud/auth/checks/actor_has_role.ex`

- [ ] **Step 1: ActorInOrg**

```elixir
defmodule OberCloud.Auth.Checks.ActorInOrg do
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_), do: "actor is a member of the resource's org"

  @impl true
  def match?(nil, _, _), do: false
  def match?(actor, %{changeset: cs}, _), do: org_id_match?(actor, extract_cs(cs))
  def match?(actor, %{query: q}, _), do: org_id_match?(actor, extract_q(q))
  def match?(_, _, _), do: false

  defp org_id_match?(%{type: :api_key, org_id: aid}, oid), do: not is_nil(oid) and aid == oid

  defp org_id_match?(%{type: :user, id: uid}, oid) when not is_nil(uid) and not is_nil(oid) do
    case OberCloud.Accounts.Membership
         |> Ash.Query.filter(user_id == ^uid and org_id == ^oid)
         |> Ash.read_one() do
      {:ok, nil} -> false
      {:ok, _} -> true
      _ -> false
    end
  end

  defp org_id_match?(_, _), do: false

  defp extract_cs(%Ash.Changeset{attributes: %{org_id: id}}), do: id
  defp extract_cs(%Ash.Changeset{data: %{org_id: id}}), do: id
  defp extract_cs(_), do: nil

  defp extract_q(_), do: nil
end
```

- [ ] **Step 2: ActorHasRole**

```elixir
defmodule OberCloud.Auth.Checks.ActorHasRole do
  use Ash.Policy.SimpleCheck

  @hierarchy %{
    "system:owner" => 100, "org:owner" => 50, "org:admin" => 40,
    "org:member" => 30, "org:viewer" => 20
  }

  @impl true
  def describe(opts), do: "actor has role >= #{inspect(opts[:role])}"

  @impl true
  def match?(nil, _, _), do: false

  def match?(%{type: :api_key, role: role}, _, opts) do
    role_satisfies?(role, Keyword.fetch!(opts, :role))
  end

  def match?(%{type: :user, id: uid}, %{changeset: cs}, opts) do
    oid = extract_org_id(cs)
    user_role_satisfies?(uid, oid, Keyword.fetch!(opts, :role))
  end

  def match?(_, _, _), do: false

  defp user_role_satisfies?(_uid, nil, _), do: false
  defp user_role_satisfies?(uid, oid, required) do
    case OberCloud.Accounts.Membership
         |> Ash.Query.filter(user_id == ^uid and org_id == ^oid)
         |> Ash.read_one() do
      {:ok, %{role: role}} -> role_satisfies?(role, required)
      _ -> false
    end
  end

  defp role_satisfies?(actor_role, required_role) do
    Map.get(@hierarchy, actor_role, 0) >= Map.get(@hierarchy, required_role, 999)
  end

  defp extract_org_id(%Ash.Changeset{attributes: %{org_id: id}}), do: id
  defp extract_org_id(%Ash.Changeset{data: %{org_id: id}}), do: id
  defp extract_org_id(_), do: nil
end
```

- [ ] **Step 3: Commit (no tests yet — Task 14 exercises)**

---

### Task 14: Apply Ash policies

**Files:** modify `org.ex`, `membership.ex`, `project.ex`, `api_key.ex`, `node.ex`; create `policies_test.exs`

- [ ] **Step 1: Failing test**

```elixir
defmodule OberCloud.PoliciesTest do
  use OberCloud.DataCase, async: true
  alias OberCloud.Accounts.{Org, Membership, User}
  alias OberCloud.Projects.Project

  setup do
    {:ok, org_a} = Ash.create(Org, %{name: "A", slug: "org-a"})
    {:ok, org_b} = Ash.create(Org, %{name: "B", slug: "org-b"})

    {:ok, alice} =
      User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "alice@a.com", name: "Alice",
        password: "secret123456", password_confirmation: "secret123456"
      })
      |> Ash.create()

    {:ok, _} = Ash.create(Membership, %{user_id: alice.id, org_id: org_a.id, role: "org:owner"})
    actor = Map.put(alice, :type, :user)
    {:ok, alice: actor, org_a: org_a, org_b: org_b}
  end

  test "owner of org A can create projects in A", %{alice: alice, org_a: org_a} do
    assert {:ok, _} =
             Project
             |> Ash.Changeset.for_create(:create, %{name: "P", slug: "p", org_id: org_a.id})
             |> Ash.create(actor: alice)
  end

  test "owner of org A cannot create projects in B", %{alice: alice, org_b: org_b} do
    assert {:error, %Ash.Error.Forbidden{}} =
             Project
             |> Ash.Changeset.for_create(:create, %{name: "P", slug: "p", org_id: org_b.id})
             |> Ash.create(actor: alice)
  end

  test "API key with org:viewer cannot create projects", %{org_a: org_a} do
    actor = %{type: :api_key, org_id: org_a.id, role: "org:viewer"}
    assert {:error, %Ash.Error.Forbidden{}} =
             Project
             |> Ash.Changeset.for_create(:create, %{name: "P", slug: "p", org_id: org_a.id})
             |> Ash.create(actor: actor)
  end

  test "API key with org:admin can create projects", %{org_a: org_a} do
    actor = %{type: :api_key, org_id: org_a.id, role: "org:admin"}
    assert {:ok, _} =
             Project
             |> Ash.Changeset.for_create(:create, %{name: "P2", slug: "p2", org_id: org_a.id})
             |> Ash.create(actor: actor)
  end
end
```

- [ ] **Step 2: Add policies to Project**

In `project.ex`, change `use Ash.Resource` to include `authorizers: [Ash.Policy.Authorizer]`. Add this `policies` block:

```elixir
policies do
  policy action_type(:read) do
    authorize_if {OberCloud.Auth.Checks.ActorInOrg, []}
  end

  policy action_type(:create) do
    authorize_if {OberCloud.Auth.Checks.ActorHasRole, role: "org:admin"}
  end

  policy action_type([:update, :destroy]) do
    authorize_if {OberCloud.Auth.Checks.ActorHasRole, role: "org:admin"}
  end
end
```

- [ ] **Step 3: Add policies to Org, Membership, ApiKey, Node**

Add `authorizers: [Ash.Policy.Authorizer]` and `policies do ... end` to each:

`org.ex`:
```elixir
policies do
  policy action_type(:read) do
    authorize_if {OberCloud.Auth.Checks.ActorInOrg, []}
  end

  policy action_type(:create) do
    authorize_if actor_present()
  end

  policy action_type([:update, :destroy]) do
    authorize_if {OberCloud.Auth.Checks.ActorHasRole, role: "org:owner"}
  end
end
```

`membership.ex`:
```elixir
policies do
  policy action_type(:read) do
    authorize_if {OberCloud.Auth.Checks.ActorInOrg, []}
  end

  policy action_type([:create, :update, :destroy]) do
    authorize_if {OberCloud.Auth.Checks.ActorHasRole, role: "org:admin"}
  end
end
```

`api_key.ex`: same pattern (admin can manage; org members can read).

`node.ex`:
```elixir
policies do
  policy action_type(:read) do
    authorize_if actor_present()
  end

  policy action_type([:create, :update, :destroy]) do
    authorize_if {OberCloud.Auth.Checks.ActorHasRole, role: "system:owner"}
  end
end
```

- [ ] **Step 4: Run tests, commit**

```bash
mix test apps/obercloud/test/obercloud/policies_test.exs
```

Expected: 4 tests pass.

---

## Phase 4: HTTP Layer

### Task 15: API key auth plug

**Files:**
- Create: `server/apps/obercloud_web/test/support/conn_case.ex`
- Create: `server/apps/obercloud_web/lib/obercloud_web/plugs/api_key_plug.ex`
- Create: `server/apps/obercloud_web/test/obercloud_web/plugs/api_key_plug_test.exs`

- [ ] **Step 1: ConnCase**

```elixir
defmodule OberCloudWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      @endpoint OberCloudWeb.Endpoint
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(OberCloud.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
```

- [ ] **Step 2: Failing test**

```elixir
defmodule OberCloudWeb.Plugs.ApiKeyPlugTest do
  use OberCloudWeb.ConnCase, async: true
  alias OberCloudWeb.Plugs.ApiKeyPlug
  alias OberCloud.{Auth.ApiKey, Accounts.Org}

  setup %{conn: conn} do
    {:ok, org} = Ash.create(Org, %{name: "Acme", slug: "acme"})
    {:ok, %{plaintext: pt}} =
      ApiKey.create_with_plaintext(%{name: "k", org_id: org.id, role: "org:admin"})
    {:ok, conn: conn, plaintext: pt}
  end

  test "sets actor on valid bearer token", %{conn: conn, plaintext: pt} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer #{pt}")
      |> ApiKeyPlug.call(ApiKeyPlug.init([]))

    assert conn.assigns.current_actor.type == :api_key
    assert conn.assigns.current_actor.role == "org:admin"
  end

  test "halts with 401 on missing token", %{conn: conn} do
    conn = ApiKeyPlug.call(conn, ApiKeyPlug.init([]))
    assert conn.status == 401
    assert conn.halted
  end

  test "halts with 401 on invalid token", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer obk_garbage")
      |> ApiKeyPlug.call(ApiKeyPlug.init([]))
    assert conn.status == 401
  end
end
```

- [ ] **Step 3: Implement plug**

```elixir
defmodule OberCloudWeb.Plugs.ApiKeyPlug do
  import Plug.Conn
  alias OberCloud.Auth.ApiKey

  def init(opts), do: opts

  def call(conn, _opts) do
    with [bearer] <- get_req_header(conn, "authorization"),
         "Bearer " <> token <- bearer,
         {:ok, key} <- ApiKey.verify(token) do
      Task.start(fn ->
        key |> Ash.Changeset.for_update(:touch_last_used) |> Ash.update()
      end)

      actor = %{type: :api_key, id: key.id, org_id: key.org_id, role: key.role}
      assign(conn, :current_actor, actor)
    else
      _ -> unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, ~s({"error": "unauthorized"}))
    |> halt()
  end
end
```

- [ ] **Step 4: Run, commit**

```bash
mix test apps/obercloud_web/test/obercloud_web/plugs/api_key_plug_test.exs
```

Expected: 3 tests pass.

---

### Task 16: AshJsonApi router + REST tests

**Files:**
- Modify: `server/apps/obercloud_web/lib/obercloud_web/router.ex`
- Create: `server/apps/obercloud_web/lib/obercloud_web/api_router.ex`
- Create: `server/apps/obercloud_web/test/obercloud_web/api/orgs_test.exs`
- Create: `server/apps/obercloud_web/test/obercloud_web/api/projects_test.exs`

- [ ] **Step 1: Failing test for orgs API**

```elixir
defmodule OberCloudWeb.Api.OrgsTest do
  use OberCloudWeb.ConnCase, async: true
  alias OberCloud.{Auth.ApiKey, Accounts.Org}

  setup %{conn: conn} do
    {:ok, org} = Ash.create(Org, %{name: "Acme", slug: "acme"})
    {:ok, %{plaintext: pt}} =
      ApiKey.create_with_plaintext(%{name: "k", org_id: org.id, role: "org:admin"})

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{pt}")
      |> put_req_header("accept", "application/vnd.api+json")
      |> put_req_header("content-type", "application/vnd.api+json")

    {:ok, conn: conn, org: org}
  end

  test "GET /api/orgs lists orgs", %{conn: conn, org: org} do
    conn = get(conn, "/api/orgs")
    body = json_response(conn, 200)
    assert Enum.any?(body["data"], fn o -> o["id"] == org.id end)
  end

  test "POST /api/orgs creates an org", %{conn: conn} do
    payload = %{
      "data" => %{
        "type" => "org",
        "attributes" => %{"name" => "New", "slug" => "new"}
      }
    }
    conn = post(conn, "/api/orgs", payload)
    assert json_response(conn, 201)["data"]["attributes"]["slug"] == "new"
  end
end
```

- [ ] **Step 2: ApiRouter**

```elixir
defmodule OberCloudWeb.ApiRouter do
  use AshJsonApi.Router,
    domains: [
      OberCloud.Accounts,
      OberCloud.Projects,
      OberCloud.ControlPlane,
      OberCloud.Auth
    ],
    open_api: "/open_api"
end
```

- [ ] **Step 3: Wire into main router**

```elixir
pipeline :api do
  plug :accepts, ["json", "json-api"]
  plug OberCloudWeb.Plugs.ApiKeyPlug
end

scope "/api" do
  pipe_through :api
  forward "/", OberCloudWeb.ApiRouter
end
```

- [ ] **Step 4: Run, write projects test, commit**

```bash
mix test apps/obercloud_web/test/obercloud_web/api/
```

Expected: 2 orgs tests pass. Add similar projects_test.exs covering create/list with relationship payload.

---

## Phase 5: Reconciler

### Task 17: Provider behaviour + Hetzner adapter

**Files:**
- Create: `lib/obercloud/providers/provider.ex`
- Create: `lib/obercloud/providers/hetzner/{client,adapter}.ex`
- Create: `test/obercloud/providers/hetzner_test.exs`

- [ ] **Step 1: Behaviour**

```elixir
defmodule OberCloud.Providers.Provider do
  @callback validate_credentials(map()) :: :ok | {:error, term()}
  @callback list_regions(map()) :: {:ok, [map()]} | {:error, term()}
  @callback list_server_types(map()) :: {:ok, [map()]} | {:error, term()}
  @callback estimate_cost(map()) :: {:ok, %{monthly_cents: integer(), currency: String.t()}}
end
```

- [ ] **Step 2: Failing test**

```elixir
defmodule OberCloud.Providers.HetznerTest do
  use ExUnit.Case, async: true
  alias OberCloud.Providers.Hetzner.Adapter

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass, base: "http://localhost:#{bypass.port}/v1"}
  end

  test "validate_credentials returns :ok on 200", %{bypass: bypass, base: base} do
    Bypass.expect_once(bypass, "GET", "/v1/locations", fn conn ->
      Plug.Conn.resp(conn, 200, ~s({"locations":[]}))
    end)
    assert :ok = Adapter.validate_credentials(%{api_token: "x", base_url: base})
  end

  test "validate_credentials returns error on 401", %{bypass: bypass, base: base} do
    Bypass.expect_once(bypass, "GET", "/v1/locations", fn conn ->
      Plug.Conn.resp(conn, 401, ~s({"error":{"message":"unauthorized"}}))
    end)
    assert {:error, _} = Adapter.validate_credentials(%{api_token: "x", base_url: base})
  end

  test "list_regions returns parsed locations", %{bypass: bypass, base: base} do
    Bypass.expect_once(bypass, "GET", "/v1/locations", fn conn ->
      Plug.Conn.resp(conn, 200, ~s({"locations":[{"name":"nbg1","city":"Nuremberg"}]}))
    end)
    assert {:ok, [%{"name" => "nbg1"}]} =
             Adapter.list_regions(%{api_token: "x", base_url: base})
  end
end
```

- [ ] **Step 3: Client + adapter**

`hetzner/client.ex`:
```elixir
defmodule OberCloud.Providers.Hetzner.Client do
  @default_base_url "https://api.hetzner.cloud/v1"

  def request(method, path, %{api_token: token} = creds, opts \\ []) do
    base = Map.get(creds, :base_url, @default_base_url)

    case Req.request(
           method: method,
           url: base <> path,
           headers: [{"authorization", "Bearer #{token}"}],
           json: opts[:json]
         ) do
      {:ok, %Req.Response{status: c, body: b}} when c in 200..299 -> {:ok, b}
      {:ok, %Req.Response{status: c, body: b}} -> {:error, {:http, c, b}}
      {:error, r} -> {:error, r}
    end
  end
end
```

`hetzner/adapter.ex`:
```elixir
defmodule OberCloud.Providers.Hetzner.Adapter do
  @behaviour OberCloud.Providers.Provider
  alias OberCloud.Providers.Hetzner.Client

  @impl true
  def validate_credentials(creds) do
    case Client.request(:get, "/locations", creds) do
      {:ok, _} -> :ok
      err -> err
    end
  end

  @impl true
  def list_regions(creds) do
    case Client.request(:get, "/locations", creds) do
      {:ok, %{"locations" => locs}} -> {:ok, locs}
      err -> err
    end
  end

  @impl true
  def list_server_types(creds) do
    case Client.request(:get, "/server_types", creds) do
      {:ok, %{"server_types" => types}} -> {:ok, types}
      err -> err
    end
  end

  @impl true
  def estimate_cost(_spec), do: {:ok, %{monthly_cents: 599, currency: "EUR"}}
end
```

- [ ] **Step 4: Run, commit**

```bash
mix test apps/obercloud/test/obercloud/providers/hetzner_test.exs
```

Expected: 3 tests pass.

---

### Task 18: HCL renderer

**Files:**
- Create: `lib/obercloud/reconciler/hcl_renderer.ex`
- Create: `test/obercloud/reconciler/hcl_renderer_test.exs`

- [ ] **Step 1: Failing test**

```elixir
defmodule OberCloud.Reconciler.HclRendererTest do
  use ExUnit.Case, async: true
  alias OberCloud.Reconciler.HclRenderer

  test "renders a single Hetzner server resource" do
    spec = %{
      "provider" => "hetzner", "resource_type" => "node",
      "name" => "ober-1", "region" => "nbg1",
      "server_type" => "cx21", "image" => "ubuntu-22.04"
    }
    hcl = HclRenderer.render(spec, "test-token", "control-plane")
    assert hcl =~ ~s(provider "hcloud")
    assert hcl =~ ~s(resource "hcloud_server" "ober_1")
    assert hcl =~ ~s(server_type = "cx21")
    assert hcl =~ ~s(location    = "nbg1")
  end

  test "escapes quotes in attribute values" do
    spec = %{
      "provider" => "hetzner", "resource_type" => "node",
      "name" => ~s(a"b), "region" => "nbg1",
      "server_type" => "cx21", "image" => "ubuntu-22.04"
    }
    hcl = HclRenderer.render(spec, "tok", "ws")
    assert hcl =~ ~s(a\\"b)
  end
end
```

- [ ] **Step 2: Implement**

```elixir
defmodule OberCloud.Reconciler.HclRenderer do
  def render(%{"provider" => "hetzner"} = spec, api_token, _ws) do
    name = sanitize(spec["name"])

    """
    terraform {
      required_providers {
        hcloud = { source = "hetznercloud/hcloud", version = "~> 1.48" }
      }
    }

    provider "hcloud" {
      token = "#{escape(api_token)}"
    }

    resource "hcloud_server" "#{name}" {
      name        = "#{escape(spec["name"])}"
      image       = "#{escape(spec["image"])}"
      server_type = "#{escape(spec["server_type"])}"
      location    = "#{escape(spec["region"])}"
    }

    output "ipv4" { value = hcloud_server.#{name}.ipv4_address }
    output "id"   { value = hcloud_server.#{name}.id }
    """
  end

  defp sanitize(name), do: String.replace(name, ~r/[^a-zA-Z0-9_]/, "_")
  defp escape(nil), do: ""
  defp escape(s) when is_binary(s), do: String.replace(s, ~s("), ~s(\\"))
end
```

- [ ] **Step 3: Run, commit**

```bash
mix test apps/obercloud/test/obercloud/reconciler/hcl_renderer_test.exs
```

Expected: 2 tests pass.

---

### Task 19: TofuRunner subprocess wrapper

**Files:**
- Create: `lib/obercloud/reconciler/tofu_runner.ex`
- Create: `test/obercloud/reconciler/tofu_runner_test.exs`
- Modify: `config/{test,dev,runtime}.exs`

- [ ] **Step 1: Configure binary path**

`config/test.exs`:
```elixir
config :obercloud, :tofu_binary, "echo"
```

`config/dev.exs` and `config/runtime.exs`:
```elixir
config :obercloud, :tofu_binary, System.get_env("OBERCLOUD_TOFU_BIN", "tofu")
```

- [ ] **Step 2: Failing test**

```elixir
defmodule OberCloud.Reconciler.TofuRunnerTest do
  use ExUnit.Case, async: true
  alias OberCloud.Reconciler.TofuRunner

  test "writes HCL, runs binary, captures output" do
    {:ok, result} = TofuRunner.run(~s(resource "null" "x" {}), ["init"])
    assert result.exit_code == 0
    assert is_binary(result.stdout)
  end
end
```

- [ ] **Step 3: Implement**

```elixir
defmodule OberCloud.Reconciler.TofuRunner do
  def run(hcl_content, args, env \\ []) do
    tmp = System.tmp_dir!() |> Path.join("ober-tofu-#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp)

    try do
      File.write!(Path.join(tmp, "main.tf"), hcl_content)
      bin = Application.fetch_env!(:obercloud, :tofu_binary)
      {output, exit_code} = System.cmd(bin, args, cd: tmp, env: env, stderr_to_stdout: true)
      {:ok, %{exit_code: exit_code, stdout: output, workdir: tmp}}
    rescue
      e -> {:error, e}
    after
      File.rm_rf(tmp)
    end
  end
end
```

- [ ] **Step 4: Run, commit**

---

### Task 20: ReconcileWorker (Oban)

**Files:**
- Modify: `config/config.exs`, `config/test.exs`
- Modify: `lib/obercloud/application.ex`
- Create: `lib/obercloud/reconciler/reconcile_worker.ex`
- Create: `test/obercloud/reconciler/reconcile_worker_test.exs`

- [ ] **Step 1: Oban config**

`config/config.exs`:
```elixir
config :obercloud, Oban,
  repo: OberCloud.Repo,
  engine: Oban.Engines.Basic,
  queues: [reconcile: 5, drift: 2],
  plugins: [
    {Oban.Plugins.Cron, crontab: [{"*/5 * * * *", OberCloud.Reconciler.DriftDetector}]}
  ]
```

`config/test.exs`:
```elixir
config :obercloud, Oban, testing: :manual
```

- [ ] **Step 2: Supervision tree**

`lib/obercloud/application.ex`:
```elixir
defmodule OberCloud.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      OberCloud.Repo,
      {Phoenix.PubSub, name: OberCloud.PubSub},
      {Oban, Application.fetch_env!(:obercloud, Oban)}
    ]
    Supervisor.start_link(children, strategy: :one_for_one, name: OberCloud.Supervisor)
  end
end
```

- [ ] **Step 3: Failing test**

```elixir
defmodule OberCloud.Reconciler.ReconcileWorkerTest do
  use OberCloud.DataCase
  use Oban.Testing, repo: OberCloud.Repo
  alias OberCloud.Reconciler.{DesiredState, ReconcileWorker}
  alias OberCloud.Accounts.Org

  setup do
    {:ok, org} = Ash.create(Org, %{name: "A", slug: "a"})
    {:ok, ds} =
      DesiredState
      |> Ash.Changeset.for_create(:create, %{
        org_id: org.id, resource_type: "node",
        resource_id: Ecto.UUID.generate(),
        spec: %{
          "provider" => "hetzner", "resource_type" => "node",
          "name" => "n1", "region" => "nbg1",
          "server_type" => "cx21", "image" => "ubuntu-22.04"
        }
      })
      |> Ash.create()
    {:ok, ds: ds}
  end

  test "marks desired_state ready after success", %{ds: ds} do
    assert :ok = perform_job(ReconcileWorker, %{"desired_state_id" => ds.id})
    reloaded = Ash.get!(DesiredState, ds.id)
    assert reloaded.reconcile_status == "ready"
  end
end
```

- [ ] **Step 4: Implement**

```elixir
defmodule OberCloud.Reconciler.ReconcileWorker do
  use Oban.Worker, queue: :reconcile, max_attempts: 5
  alias OberCloud.Reconciler.{DesiredState, HclRenderer, TofuRunner}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"desired_state_id" => id}}) do
    ds = Ash.get!(DesiredState, id)
    {:ok, _} = ds |> Ash.Changeset.for_update(:mark_reconciling) |> Ash.update()

    case do_reconcile(ds) do
      :ok ->
        ds |> Ash.Changeset.for_update(:mark_ready) |> Ash.update()
        broadcast(ds)
        :ok

      {:error, reason} ->
        ds |> Ash.Changeset.for_update(:mark_failed, %{error: inspect(reason)}) |> Ash.update()
        broadcast(ds)
        {:error, reason}
    end
  end

  defp do_reconcile(ds) do
    hcl = HclRenderer.render(ds.spec, "test-stub-token", "ds-#{ds.id}")

    with {:ok, %{exit_code: 0}} <- TofuRunner.run(hcl, ["init", "-no-color"]),
         {:ok, %{exit_code: 0}} <- TofuRunner.run(hcl, ["apply", "-auto-approve", "-no-color"]) do
      :ok
    else
      {:ok, %{exit_code: code, stdout: out}} -> {:error, "tofu exit #{code}: #{out}"}
      err -> err
    end
  end

  defp broadcast(ds) do
    Phoenix.PubSub.broadcast(OberCloud.PubSub, "desired_state:#{ds.org_id}", {:reconcile_update, ds})
  end
end
```

- [ ] **Step 5: Run, commit**

---

### Task 21: DriftDetector cron worker

**Files:**
- Create: `lib/obercloud/reconciler/drift_detector.ex`
- Create: `test/obercloud/reconciler/drift_detector_test.exs`

- [ ] **Step 1: Failing test**

```elixir
defmodule OberCloud.Reconciler.DriftDetectorTest do
  use OberCloud.DataCase
  use Oban.Testing, repo: OberCloud.Repo
  alias OberCloud.Reconciler.{DesiredState, DriftDetector}
  alias OberCloud.Accounts.Org

  test "enqueues reconcile jobs for drifted resources" do
    {:ok, org} = Ash.create(Org, %{name: "A", slug: "a"})
    {:ok, ds} =
      DesiredState
      |> Ash.Changeset.for_create(:create, %{
        org_id: org.id, resource_type: "node",
        resource_id: Ecto.UUID.generate(), spec: %{}
      })
      |> Ash.create()
    {:ok, _} = ds |> Ash.Changeset.for_update(:mark_drifted) |> Ash.update()

    assert :ok = perform_job(DriftDetector, %{})
    assert_enqueued worker: OberCloud.Reconciler.ReconcileWorker
  end
end
```

- [ ] **Step 2: Implement**

```elixir
defmodule OberCloud.Reconciler.DriftDetector do
  use Oban.Worker, queue: :drift
  alias OberCloud.Reconciler.{DesiredState, ReconcileWorker}

  @impl Oban.Worker
  def perform(_job) do
    drifted =
      DesiredState
      |> Ash.Query.filter(reconcile_status == "drifted")
      |> Ash.read!()

    Enum.each(drifted, fn ds ->
      %{desired_state_id: ds.id} |> ReconcileWorker.new() |> Oban.insert!()
    end)

    :ok
  end
end
```

- [ ] **Step 3: Run, commit**

---

## Phase 6: LiveView UI

### Task 22: AshAuthentication.Phoenix integration

**Files:**
- Modify: `lib/obercloud_web/router.ex`
- Create: `lib/obercloud_web/controllers/auth_controller.ex`
- Create: `lib/obercloud_web/live_user_auth.ex`
- Create: `test/obercloud_web/live/login_live_test.exs`

- [ ] **Step 1: Wire AshAuthentication into router**

```elixir
defmodule OberCloudWeb.Router do
  use OberCloudWeb, :router
  use AshAuthentication.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OberCloudWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json", "json-api"]
    plug OberCloudWeb.Plugs.ApiKeyPlug
  end

  scope "/api" do
    pipe_through :api
    forward "/", OberCloudWeb.ApiRouter
  end

  scope "/", OberCloudWeb do
    pipe_through :browser

    auth_routes_for OberCloud.Accounts.User, to: AuthController
    sign_out_route AuthController

    live_session :authenticated,
      on_mount: [{OberCloudWeb.LiveUserAuth, :live_user_required}] do
      live "/", DashboardLive
      live "/orgs", OrgsLive
      live "/projects", ProjectsLive
      live "/nodes", NodesLive
      live "/api_keys", ApiKeysLive
    end

    live_session :guest,
      on_mount: [{OberCloudWeb.LiveUserAuth, :live_no_user}] do
      sign_in_route(register_path: "/register")
    end
  end
end
```

- [ ] **Step 2: AuthController**

```elixir
defmodule OberCloudWeb.AuthController do
  use OberCloudWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, _activity, user, _token) do
    conn
    |> store_in_session(user)
    |> assign(:current_user, user)
    |> redirect(to: "/")
  end

  def failure(conn, _activity, _reason) do
    conn
    |> put_flash(:error, "Sign in failed")
    |> redirect(to: "/sign-in")
  end

  def sign_out(conn, _params) do
    conn |> clear_session() |> redirect(to: "/sign-in")
  end
end
```

- [ ] **Step 3: LiveUserAuth**

```elixir
defmodule OberCloudWeb.LiveUserAuth do
  use AshAuthentication.Phoenix.LiveSession

  def on_mount(:live_user_required, _params, _session, socket) do
    if socket.assigns[:current_user],
      do: {:cont, socket},
      else: {:halt, Phoenix.LiveView.redirect(socket, to: "/sign-in")}
  end

  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user],
      do: {:halt, Phoenix.LiveView.redirect(socket, to: "/")},
      else: {:cont, socket}
  end
end
```

- [ ] **Step 4: Test**

```elixir
defmodule OberCloudWeb.LoginLiveTest do
  use OberCloudWeb.ConnCase, async: true

  test "renders the sign-in form", %{conn: conn} do
    conn = get(conn, "/sign-in")
    assert html_response(conn, 200) =~ "Sign in"
  end

  test "redirects unauthenticated users to /sign-in", %{conn: conn} do
    conn = get(conn, "/")
    assert redirected_to(conn) =~ "/sign-in"
  end
end
```

- [ ] **Step 5: Run, commit**

---

### Task 23: DashboardLive

**Files:**
- Create: `lib/obercloud_web/live/dashboard_live.ex`
- Create: `test/obercloud_web/live/dashboard_live_test.exs`

- [ ] **Step 1: Failing test**

```elixir
defmodule OberCloudWeb.DashboardLiveTest do
  use OberCloudWeb.ConnCase, async: true
  alias OberCloud.Accounts.{Org, Membership, User}

  setup %{conn: conn} do
    {:ok, org} = Ash.create(Org, %{name: "A", slug: "a"})
    {:ok, user} =
      User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "u@u.com", name: "U",
        password: "secret123456", password_confirmation: "secret123456"
      })
      |> Ash.create()
    {:ok, _} = Ash.create(Membership, %{user_id: user.id, org_id: org.id, role: "org:owner"})

    conn = AshAuthentication.Phoenix.Plug.store_in_session(conn, user)
    {:ok, conn: conn}
  end

  test "shows summary cards", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")
    assert html =~ "Orgs"
    assert html =~ "Projects"
    assert html =~ "Nodes"
  end
end
```

- [ ] **Step 2: Implement**

```elixir
defmodule OberCloudWeb.DashboardLive do
  use OberCloudWeb, :live_view
  alias OberCloud.{Accounts.Org, Projects.Project, ControlPlane.Node}

  def mount(_params, _session, socket) do
    actor = Map.put(socket.assigns.current_user, :type, :user)

    {:ok,
     socket
     |> assign(:orgs_count, count(Org, actor))
     |> assign(:projects_count, count(Project, actor))
     |> assign(:nodes_count, count(Node, actor))}
  end

  defp count(resource, actor) do
    case Ash.count(resource, actor: actor) do
      {:ok, n} -> n
      _ -> 0
    end
  end

  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-3 gap-4">
      <.stat title="Orgs" value={@orgs_count} />
      <.stat title="Projects" value={@projects_count} />
      <.stat title="Nodes" value={@nodes_count} />
    </div>
    """
  end

  defp stat(assigns) do
    ~H"""
    <div class="rounded border p-4">
      <p class="text-sm text-gray-500">{@title}</p>
      <p class="text-3xl font-semibold">{@value}</p>
    </div>
    """
  end
end
```

- [ ] **Step 3: Run, commit**

---

### Task 24: Orgs / Projects / Nodes / ApiKeys LiveViews

For each resource page, create a LiveView with this shared shape:

1. `mount/3`: load list scoped to actor; subscribe to PubSub `"<resource>:#{user.id}"`
2. `handle_event("create", params, socket)`: call AshPhoenix.Form submission
3. `handle_event("delete", %{"id" => id}, socket)`: destroy resource; broadcast
4. `handle_info({:resource_update, _row}, socket)`: refresh list

Per LiveView (4 separate sub-tasks):

- [ ] **Step 1: Implement OrgsLive + test**
- [ ] **Step 2: Implement ProjectsLive + test**
- [ ] **Step 3: Implement NodesLive + test (uses NodeStatusBadge LiveVue component from Task 26)**
- [ ] **Step 4: Implement ApiKeysLive + test (uses ApiKeyForm LiveVue component from Task 26; shows plaintext exactly once after creation)**
- [ ] **Step 5: Commit after each**

---

## Phase 7: LiveVue + Vue Components

### Task 25: Assets pipeline

**Files:**
- Create: `assets/{package.json,tsconfig.json,vite.config.ts,vitest.config.ts}`
- Create: `assets/js/app.js`
- Create: `assets/js/vue/index.ts`

- [ ] **Step 1: package.json**

```json
{
  "name": "obercloud_web",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "vite build",
    "dev": "vite",
    "test": "vitest run",
    "test:watch": "vitest",
    "lint": "tsc --noEmit"
  },
  "dependencies": {
    "phoenix": "^1.7.14",
    "phoenix_html": "^4.1.1",
    "phoenix_live_view": "^1.0.0",
    "live_vue": "^0.5.0",
    "vue": "^3.5.0"
  },
  "devDependencies": {
    "@vitejs/plugin-vue": "^5.1.0",
    "@vue/test-utils": "^2.4.6",
    "vite": "^5.4.0",
    "vitest": "^2.1.0",
    "happy-dom": "^15.0.0",
    "typescript": "^5.6.0"
  }
}
```

- [ ] **Step 2: tsconfig.json**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "jsx": "preserve",
    "esModuleInterop": true,
    "skipLibCheck": true,
    "types": ["vite/client", "vitest/globals"]
  },
  "include": ["js/**/*", "test/**/*"]
}
```

- [ ] **Step 3: vite.config.ts**

```ts
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import path from 'path'

export default defineConfig({
  plugins: [vue()],
  build: {
    outDir: '../priv/static/assets',
    emptyOutDir: true,
    rollupOptions: {
      input: { app: path.resolve(__dirname, 'js/app.js') }
    }
  }
})
```

- [ ] **Step 4: vitest.config.ts**

```ts
import { defineConfig } from 'vitest/config'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  test: {
    environment: 'happy-dom',
    globals: true,
    include: ['test/**/*.test.ts']
  }
})
```

- [ ] **Step 5: js/app.js**

```js
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import { getHooks } from "live_vue";
import components from "./vue";

const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content");
const liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: getHooks(components)
});
liveSocket.connect();
```

- [ ] **Step 6: js/vue/index.ts**

```ts
import OrgSwitcher from './OrgSwitcher.vue'
import NodeStatusBadge from './NodeStatusBadge.vue'
import ApiKeyForm from './ApiKeyForm.vue'
import ResourceTable from './ResourceTable.vue'

export default { OrgSwitcher, NodeStatusBadge, ApiKeyForm, ResourceTable }
```

- [ ] **Step 7: Install + commit**

```bash
cd /home/milad/dev/OberCloud/server/apps/obercloud_web/assets
npm install
```

---

### Task 26: Vue components (test-first)

For each component: write Vitest test → implement SFC → `npm run test` → commit.

#### NodeStatusBadge

`test/NodeStatusBadge.test.ts`:
```ts
import { mount } from '@vue/test-utils'
import { describe, it, expect } from 'vitest'
import NodeStatusBadge from '../js/vue/NodeStatusBadge.vue'

describe('NodeStatusBadge', () => {
  it('renders status text', () => {
    const w = mount(NodeStatusBadge, { props: { status: 'ready' } })
    expect(w.text()).toBe('ready')
  })

  it('applies green class for ready', () => {
    const w = mount(NodeStatusBadge, { props: { status: 'ready' } })
    expect(w.classes()).toContain('bg-green-200')
  })

  it('applies yellow class for provisioning', () => {
    const w = mount(NodeStatusBadge, { props: { status: 'provisioning' } })
    expect(w.classes()).toContain('bg-yellow-200')
  })
})
```

`js/vue/NodeStatusBadge.vue`:
```vue
<script setup lang="ts">
defineProps<{ status: 'provisioning' | 'ready' | 'degraded' | 'decommissioned' }>()
const colors = {
  provisioning: 'bg-yellow-200 text-yellow-800',
  ready: 'bg-green-200 text-green-800',
  degraded: 'bg-orange-200 text-orange-800',
  decommissioned: 'bg-gray-200 text-gray-700'
} as const
</script>

<template>
  <span :class="['px-2 py-1 rounded text-xs', colors[status]]">{{ status }}</span>
</template>
```

#### OrgSwitcher

Props: `orgs: Org[]`, `activeOrgId: string`. Emits `change` with new org id. Test asserts that changing the `<select>` emits `change`.

#### ApiKeyForm

Props: `roles: string[]`. Emits `submit` with `{name, role, expiresAt}`. Test asserts emission with correct payload.

#### ResourceTable

Props: `columns: {key, label}[]`, `rows: any[]`. Renders an HTML table. Tests: renders headers, renders one row per item.

- [ ] **Step 1: NodeStatusBadge** (test → impl → commit)
- [ ] **Step 2: OrgSwitcher**
- [ ] **Step 3: ApiKeyForm**
- [ ] **Step 4: ResourceTable**

Wire each component into the appropriate LiveView via:
```heex
<.vue v-component="NodeStatusBadge" v-props={Jason.encode!(%{status: @node.status})} />
```

---

## Phase 8: Rust CLI Implementation

### Task 27: Config file management

**Files:**
- Replace stub: `cli/src/config.rs`
- Create: `cli/tests/config_test.rs`

- [ ] **Step 1: Failing test**

```rust
use obercloud::config::{Config, Context};

#[test]
fn config_roundtrip() {
    let mut cfg = Config::default();
    cfg.active_context = Some("prod".into());
    cfg.contexts.insert("prod".into(), Context {
        url: "https://prod.example.com".into(),
        api_key: Some("obk_test".into()),
    });
    let s = toml::to_string(&cfg).unwrap();
    let parsed: Config = toml::from_str(&s).unwrap();
    assert_eq!(parsed.active_context.as_deref(), Some("prod"));
    assert_eq!(parsed.contexts["prod"].url, "https://prod.example.com");
}
```

- [ ] **Step 2: Implement**

```rust
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::path::PathBuf;
use crate::{CliError, Result};

#[derive(Debug, Default, Serialize, Deserialize)]
pub struct Config {
    pub active_context: Option<String>,
    #[serde(default)]
    pub contexts: BTreeMap<String, Context>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Context {
    pub url: String,
    pub api_key: Option<String>,
}

impl Config {
    pub fn path() -> PathBuf {
        dirs::config_dir().expect("no config dir").join("obercloud").join("config.toml")
    }

    pub fn load() -> Result<Self> {
        let p = Self::path();
        if !p.exists() { return Ok(Self::default()); }
        Ok(toml::from_str(&std::fs::read_to_string(&p)?)?)
    }

    pub fn save(&self) -> Result<()> {
        let p = Self::path();
        if let Some(parent) = p.parent() { std::fs::create_dir_all(parent)?; }
        std::fs::write(&p, toml::to_string_pretty(self)?)?;
        Ok(())
    }

    pub fn active(&self) -> Result<&Context> {
        let n = self.active_context.as_ref().ok_or(CliError::NoActiveContext)?;
        self.contexts.get(n).ok_or(CliError::NoActiveContext)
    }
}
```

- [ ] **Step 3: Run, commit**

```bash
cd /home/milad/dev/OberCloud/cli
cargo test config_roundtrip
```

Expected: 1 test passes.

---

### Task 28: HTTP client wrapper

**Files:**
- Replace stub: `cli/src/client.rs`
- Create: `cli/tests/client_test.rs`

- [ ] **Step 1: Failing test (mockito)**

```rust
use mockito::Server;
use serde_json::json;

#[tokio::test]
async fn client_get_returns_parsed_json() {
    let mut server = Server::new_async().await;
    let _m = server.mock("GET", "/api/orgs")
        .with_status(200)
        .with_header("content-type", "application/vnd.api+json")
        .with_body(json!({"data": []}).to_string())
        .create_async().await;

    let client = obercloud::client::Client::new_for_test(&server.url(), "obk_test");
    let body: serde_json::Value = client.get("/api/orgs").await.unwrap();
    assert_eq!(body["data"], json!([]));
}
```

- [ ] **Step 2: Implement**

```rust
use crate::{config::Config, CliError, Result};
use serde::{de::DeserializeOwned, Serialize};

pub struct Client {
    base_url: String,
    api_key: String,
    http: reqwest::Client,
}

impl Client {
    pub fn from_config() -> Result<Self> {
        let cfg = Config::load()?;
        let ctx = cfg.active()?;
        let api_key = ctx.api_key.clone()
            .ok_or_else(|| CliError::Config("no api_key — run `obercloud auth login`".into()))?;
        Ok(Self::new_for_test(&ctx.url, &api_key))
    }

    pub fn new_for_test(url: &str, api_key: &str) -> Self {
        Self {
            base_url: url.to_string(),
            api_key: api_key.to_string(),
            http: reqwest::Client::new(),
        }
    }

    pub async fn get<T: DeserializeOwned>(&self, path: &str) -> Result<T> {
        let r = self.http.get(format!("{}{}", self.base_url, path))
            .bearer_auth(&self.api_key)
            .header("accept", "application/vnd.api+json")
            .send().await?;
        Self::parse(r).await
    }

    pub async fn post<B: Serialize, T: DeserializeOwned>(&self, path: &str, body: &B) -> Result<T> {
        let r = self.http.post(format!("{}{}", self.base_url, path))
            .bearer_auth(&self.api_key)
            .header("accept", "application/vnd.api+json")
            .header("content-type", "application/vnd.api+json")
            .json(body).send().await?;
        Self::parse(r).await
    }

    pub async fn delete(&self, path: &str) -> Result<()> {
        let r = self.http.delete(format!("{}{}", self.base_url, path))
            .bearer_auth(&self.api_key).send().await?;
        if !r.status().is_success() {
            let status = r.status().as_u16();
            return Err(CliError::Api { status, message: r.text().await? });
        }
        Ok(())
    }

    async fn parse<T: DeserializeOwned>(r: reqwest::Response) -> Result<T> {
        if r.status().is_success() {
            Ok(r.json().await?)
        } else {
            let status = r.status().as_u16();
            Err(CliError::Api { status, message: r.text().await? })
        }
    }
}
```

- [ ] **Step 3: Run, commit**

---

### Task 29: Context + Auth commands

**Files:**
- Replace stubs: `cli/src/commands/context.rs`, `cli/src/commands/auth.rs`

- [ ] **Step 1: context.rs**

```rust
use clap::Subcommand;
use crate::{config::{Config, Context}, output, Result, CliError};

#[derive(Subcommand)]
pub enum ContextCommand {
    Add { name: String, url: String },
    Use { name: String },
    List,
}

pub async fn run(cmd: ContextCommand) -> Result<()> {
    let mut cfg = Config::load()?;
    match cmd {
        ContextCommand::Add { name, url } => {
            cfg.contexts.insert(name.clone(), Context { url, api_key: None });
            if cfg.active_context.is_none() { cfg.active_context = Some(name.clone()); }
            cfg.save()?;
            output::success(&format!("added context '{}'", name));
        }
        ContextCommand::Use { name } => {
            if !cfg.contexts.contains_key(&name) {
                return Err(CliError::Config(format!("no such context '{}'", name)));
            }
            cfg.active_context = Some(name.clone());
            cfg.save()?;
            output::success(&format!("active context: {}", name));
        }
        ContextCommand::List => {
            for (name, ctx) in &cfg.contexts {
                let m = if cfg.active_context.as_deref() == Some(name) { "*" } else { " " };
                println!("{} {} ({})", m, name, ctx.url);
            }
        }
    }
    Ok(())
}
```

- [ ] **Step 2: auth.rs**

```rust
use clap::Subcommand;
use dialoguer::{Input, Password};
use serde_json::json;
use crate::{client::Client, config::Config, output, Result, CliError};

#[derive(Subcommand)]
pub enum AuthCommand {
    Login,
}

pub async fn run(cmd: AuthCommand) -> Result<()> {
    match cmd {
        AuthCommand::Login => {
            let mut cfg = Config::load()?;
            let active_name = cfg.active_context.clone().ok_or(CliError::NoActiveContext)?;
            let url = cfg.contexts.get(&active_name).ok_or(CliError::NoActiveContext)?.url.clone();

            let email: String = Input::new().with_prompt("Email").interact_text()
                .map_err(|e| CliError::Validation(e.to_string()))?;
            let password = Password::new().with_prompt("Password").interact()
                .map_err(|e| CliError::Validation(e.to_string()))?;

            let body = json!({
                "data": {"type": "user", "attributes": {"email": email, "password": password}}
            });

            let client = Client::new_for_test(&url, "");
            let resp: serde_json::Value = client.post("/auth/user/password/sign_in", &body).await?;
            let token = resp["data"]["attributes"]["token"].as_str()
                .ok_or_else(|| CliError::Validation("no token in response".into()))?;

            cfg.contexts.get_mut(&active_name).unwrap().api_key = Some(token.to_string());
            cfg.save()?;
            output::success("authenticated");
        }
    }
    Ok(())
}
```

- [ ] **Step 3: Mockito test for context add/use round-trip + commit**

---

### Task 30: Resource commands

For each module (`orgs`, `users`, `projects`, `nodes`, `apikeys`), implement using `Client::from_config()`. Standard shape (`orgs.rs` example):

```rust
use clap::Subcommand;
use serde_json::json;
use crate::{client::Client, output, Result};

#[derive(Subcommand)]
pub enum OrgsCommand {
    List,
    Create { name: String, slug: String },
    Delete { id: String },
}

pub async fn run(cmd: OrgsCommand) -> Result<()> {
    let client = Client::from_config()?;
    match cmd {
        OrgsCommand::List => {
            let resp: serde_json::Value = client.get("/api/orgs").await?;
            for org in resp["data"].as_array().unwrap_or(&vec![]) {
                println!("{}  {}",
                    org["id"].as_str().unwrap_or(""),
                    org["attributes"]["name"].as_str().unwrap_or(""));
            }
        }
        OrgsCommand::Create { name, slug } => {
            let body = json!({
                "data": {"type": "org", "attributes": {"name": name, "slug": slug}}
            });
            let resp: serde_json::Value = client.post("/api/orgs", &body).await?;
            output::success(&format!("created org {}",
                resp["data"]["id"].as_str().unwrap_or("?")));
        }
        OrgsCommand::Delete { id } => {
            client.delete(&format!("/api/orgs/{}", id)).await?;
            output::success(&format!("deleted org {}", id));
        }
    }
    Ok(())
}
```

- [ ] **Step 1: orgs.rs** (impl + mockito test + commit)
- [ ] **Step 2: projects.rs**
- [ ] **Step 3: nodes.rs**
- [ ] **Step 4: apikeys.rs** (with `Revoke {id}` variant — DELETE on `/api/api_keys/{id}`)
- [ ] **Step 5: users.rs** (`Invite { email, role, org_id }` POSTs to `/api/users/invite` — define matching action on User Ash resource)

---

### Task 31: Bootstrap (init/destroy/upgrade) + OpenTofu templates

**Files:**
- Create: `cli/src/commands/bootstrap/tofu.rs`
- Create: `cli/src/commands/bootstrap/templates/{single_node.tf,multi_node.tf,cloud_init.yaml}`
- Replace stubs: `init.rs`, `destroy.rs`, `upgrade.rs`

- [ ] **Step 1: HCL templates (embed via `include_str!`)**

`single_node.tf`:
```hcl
terraform {
  required_providers {
    hcloud = { source = "hetznercloud/hcloud", version = "~> 1.48" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

variable "hetzner_token" {}
variable "region"      { default = "nbg1" }
variable "server_type" { default = "cx21" }
variable "ssh_pubkey"  {}

provider "hcloud" { token = var.hetzner_token }

resource "random_password" "db_password"     { length = 32 ; special = false }
resource "random_password" "secret_key_base" { length = 64 ; special = false }
resource "random_password" "encryption_key"  { length = 32 ; special = false }

resource "hcloud_ssh_key" "boot" {
  name       = "obercloud-boot"
  public_key = var.ssh_pubkey
}

resource "hcloud_server" "control_plane" {
  name        = "obercloud-cp"
  image       = "ubuntu-22.04"
  server_type = var.server_type
  location    = var.region
  ssh_keys    = [hcloud_ssh_key.boot.id]

  user_data = templatefile("${path.module}/cloud_init.yaml", {
    db_password     = random_password.db_password.result
    secret_key_base = random_password.secret_key_base.result
    encryption_key  = random_password.encryption_key.result
  })
}

output "url"            { value = "http://${hcloud_server.control_plane.ipv4_address}" }
output "admin_email"    { value = "admin@obercloud.local" }
output "admin_password" { value = random_password.db_password.result ; sensitive = true }
```

`multi_node.tf`: similar but provisions 3 servers and configures PostgreSQL primary + 2 standbys; cloud-init joins Elixir nodes via libcluster.

`cloud_init.yaml`:
```yaml
#cloud-config
package_update: true
packages:
  - docker.io
  - postgresql-16
  - postgresql-contrib

write_files:
  - path: /etc/obercloud/env
    content: |
      DATABASE_URL=postgres://obercloud:${db_password}@localhost/obercloud
      SECRET_KEY_BASE=${secret_key_base}
      CREDENTIAL_ENCRYPTION_KEY=${encryption_key}
    permissions: '0600'

runcmd:
  - sudo -u postgres psql -c "CREATE USER obercloud WITH PASSWORD '${db_password}';"
  - sudo -u postgres psql -c "CREATE DATABASE obercloud OWNER obercloud;"
  - docker run -d --name obercloud --restart unless-stopped --network host --env-file /etc/obercloud/env ghcr.io/obercloud/obercloud:latest
```

- [ ] **Step 2: tofu.rs subprocess wrapper**

```rust
use std::path::Path;
use std::process::{Command, Stdio};
use crate::{CliError, Result};

pub fn run(workdir: &Path, args: &[&str]) -> Result<String> {
    let output = Command::new("tofu")
        .args(args)
        .current_dir(workdir)
        .stdin(Stdio::null())
        .stderr(Stdio::inherit())
        .output()?;

    if !output.status.success() {
        return Err(CliError::Tofu(format!("tofu {:?} failed", args)));
    }
    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}
```

- [ ] **Step 3: init.rs**

```rust
use clap::Args as ClapArgs;
use dialoguer::{Password, Select};
use std::fs;
use crate::{config::{Config, Context}, output, Result, CliError};
use super::tofu;

#[derive(ClapArgs)]
pub struct Args {
    #[arg(long)] pub token: Option<String>,
    #[arg(long, default_value = "nbg1")] pub region: String,
    #[arg(long, default_value_t = 1)] pub nodes: u8,
}

pub async fn run(args: Args) -> Result<()> {
    output::info("OberCloud bootstrap (Hetzner)");

    let token = match args.token {
        Some(t) => t,
        None => Password::new().with_prompt("Hetzner API token").interact()
            .map_err(|e| CliError::Validation(e.to_string()))?,
    };

    let providers = &["Hetzner"];
    Select::new().with_prompt("Provider").items(providers).default(0).interact().ok();

    let nodes = args.nodes;
    if nodes != 1 && nodes != 3 {
        return Err(CliError::Validation("nodes must be 1 or 3".into()));
    }

    let template = if nodes == 1 {
        include_str!("templates/single_node.tf")
    } else {
        include_str!("templates/multi_node.tf")
    };
    let cloud_init = include_str!("templates/cloud_init.yaml");

    let workdir = tempfile::tempdir()?;
    fs::write(workdir.path().join("main.tf"), template)?;
    fs::write(workdir.path().join("cloud_init.yaml"), cloud_init)?;

    let ssh_pubkey = fs::read_to_string(dirs::home_dir().unwrap().join(".ssh/id_ed25519.pub"))
        .or_else(|_| fs::read_to_string(dirs::home_dir().unwrap().join(".ssh/id_rsa.pub")))?;

    fs::write(
        workdir.path().join("terraform.tfvars"),
        format!(
            "hetzner_token = \"{}\"\nregion = \"{}\"\nssh_pubkey = \"{}\"\n",
            token, args.region, ssh_pubkey.trim()
        ),
    )?;

    output::info("running tofu init");
    tofu::run(workdir.path(), &["init", "-no-color"])?;

    output::info("running tofu apply");
    tofu::run(workdir.path(), &["apply", "-auto-approve", "-no-color"])?;

    let out_json = tofu::run(workdir.path(), &["output", "-json"])?;
    let outputs: serde_json::Value = serde_json::from_str(&out_json)
        .map_err(|e| CliError::Tofu(e.to_string()))?;

    let url = outputs["url"]["value"].as_str().unwrap_or("").to_string();
    let admin_password = outputs["admin_password"]["value"].as_str().unwrap_or("").to_string();

    output::info(&format!("waiting for {} to come up", url));
    wait_for_health(&url).await?;

    let mut cfg = Config::load()?;
    cfg.contexts.insert("default".into(), Context { url: url.clone(), api_key: None });
    cfg.active_context = Some("default".into());
    cfg.save()?;

    // Persist tfvars for destroy/upgrade later
    let cfg_dir = Config::path().parent().unwrap().join("default");
    fs::create_dir_all(&cfg_dir)?;
    fs::write(cfg_dir.join("main.tf"), template)?;
    fs::write(cfg_dir.join("cloud_init.yaml"), cloud_init)?;
    fs::copy(workdir.path().join("terraform.tfvars"), cfg_dir.join("terraform.tfvars"))?;
    fs::create_dir_all(cfg_dir.join(".terraform"))?;
    let tofu_state_src = workdir.path().join("terraform.tfstate");
    if tofu_state_src.exists() {
        fs::copy(&tofu_state_src, cfg_dir.join("terraform.tfstate"))?;
    }

    output::success(&format!("OberCloud is running at {}", url));
    output::success(&format!("admin password: {}", admin_password));
    output::info("run `obercloud auth login` to sign in");
    Ok(())
}

async fn wait_for_health(url: &str) -> Result<()> {
    let client = reqwest::Client::new();
    for _ in 0..60 {
        if let Ok(r) = client.get(format!("{}/health", url)).send().await {
            if r.status().is_success() { return Ok(()); }
        }
        tokio::time::sleep(std::time::Duration::from_secs(5)).await;
    }
    Err(CliError::Tofu("control plane never became healthy".into()))
}
```

- [ ] **Step 4: destroy.rs**

```rust
use clap::Args as ClapArgs;
use crate::{config::Config, output, Result};
use super::tofu;

#[derive(ClapArgs)]
pub struct Args {}

pub async fn run(_args: Args) -> Result<()> {
    let cfg_dir = Config::path().parent().unwrap().join("default");
    output::info("running tofu destroy");
    tofu::run(&cfg_dir, &["destroy", "-auto-approve", "-no-color"])?;
    output::success("control plane destroyed");
    Ok(())
}
```

- [ ] **Step 5: upgrade.rs**

```rust
use clap::Args as ClapArgs;
use crate::{config::Config, output, Result};
use super::tofu;

#[derive(ClapArgs)]
pub struct Args {
    #[arg(long, default_value = "latest")] pub version: String,
}

pub async fn run(args: Args) -> Result<()> {
    let cfg_dir = Config::path().parent().unwrap().join("default");
    output::info(&format!("upgrading to obercloud {}", args.version));
    // tfvars already in cfg_dir; user may pass new server image / image tag through env
    tofu::run(&cfg_dir, &["apply", "-auto-approve", "-no-color"])?;
    output::success("upgrade complete");
    Ok(())
}
```

- [ ] **Step 6: Help-output test (`assert_cmd`)**

`cli/tests/commands_test.rs`:
```rust
use assert_cmd::Command;
use predicates::prelude::*;

#[test]
fn help_lists_subcommands() {
    let mut cmd = Command::cargo_bin("obercloud").unwrap();
    cmd.arg("--help");
    cmd.assert()
        .success()
        .stdout(predicate::str::contains("init"))
        .stdout(predicate::str::contains("context"))
        .stdout(predicate::str::contains("orgs"));
}
```

- [ ] **Step 7: Run, commit**

```bash
cd /home/milad/dev/OberCloud/cli
cargo test
```

Expected: all tests pass.

---

## Phase 9: CI Pipeline

### Task 32: GitHub Actions workflow

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Workflow**

```yaml
name: CI

on:
  push:         { branches: [main] }
  pull_request: { branches: [main] }

jobs:
  elixir:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: obercloud_test
        ports: ["5432:5432"]
        options: >-
          --health-cmd pg_isready --health-interval 10s
          --health-timeout 5s --health-retries 5
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with: { elixir-version: "1.19", otp-version: "28" }
      - uses: actions/setup-node@v4
        with: { node-version: "20" }
      - run: mix deps.get
        working-directory: server
      - run: mix compile --warnings-as-errors
        working-directory: server
        env: { MIX_ENV: test }
      - run: mix ecto.create && mix ecto.migrate
        working-directory: server
        env:
          MIX_ENV: test
          DATABASE_URL: postgres://postgres:postgres@localhost/obercloud_test
      - run: mix test
        working-directory: server
        env:
          MIX_ENV: test
          DATABASE_URL: postgres://postgres:postgres@localhost/obercloud_test
      - run: npm ci
        working-directory: server/apps/obercloud_web/assets
      - run: npm run test
        working-directory: server/apps/obercloud_web/assets
      - run: npm run lint
        working-directory: server/apps/obercloud_web/assets

  rust:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - run: cargo fmt --check
        working-directory: cli
      - run: cargo clippy --all-targets -- -D warnings
        working-directory: cli
      - run: cargo test
        working-directory: cli
      - run: cargo build --release
        working-directory: cli
```

- [ ] **Step 2: Commit**

---

## Self-Review Checklist

- [ ] Every spec section (1–11) has at least one task implementing it
- [ ] No `TODO` / `TBD` / placeholder steps remain
- [ ] All Ash resource module names are consistent across definition and references
- [ ] Test commands and expected outputs are specific
- [ ] CLI command signatures in `main.rs` match the per-module command enums
- [ ] No `git` commands invoked — uses checkpoint pauses for jj
- [ ] Project paths use `/home/milad/dev/OberCloud` consistently

---

## Out of Scope (deferred from spec section 10)

P1+ tasks: VM/resource provisioning beyond the control plane itself, WireGuard overlay, managed services (PostgreSQL/load balancer/etc.), app deployment, autoscaling, lambda execution, Tailscale, reseller UI, Bounce AI Ops, Terraform provider plugin, DigitalOcean adapter, pricing transparency UI, Playwright E2E, Rust NIFs.
