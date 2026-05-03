# OberCloud — Installation Guide

This guide covers two scenarios:

- **[Local development](#1-local-development)** — running OberCloud on your laptop to try it out, contribute, or evaluate the codebase.
- **[Production bootstrap](#2-production-bootstrap-on-hetzner)** — provisioning a real OberCloud installation on Hetzner via the `obercloud` CLI. *(Pre-alpha — see the [Production caveats](#production-caveats) section before you try this.)*

If you're just kicking the tires, do [Local development](#1-local-development) first.

---

## Table of contents

1. [Local development](#1-local-development)
   - [Prerequisites](#prerequisites)
   - [Clone and bootstrap the repo](#clone-and-bootstrap-the-repo)
   - [Run the server](#run-the-server)
   - [Build the CLI](#build-the-cli)
   - [Smoke test: sign up, create an org, hit the API](#smoke-test-sign-up-create-an-org-hit-the-api)
   - [Running the test suites](#running-the-test-suites)
2. [Production bootstrap on Hetzner](#2-production-bootstrap-on-hetzner)
3. [Configuration reference](#configuration-reference)
4. [Troubleshooting](#troubleshooting)

---

## 1. Local development

### Prerequisites

| Tool | Version | Why |
|---|---|---|
| Elixir | **1.19.2+** | Server language |
| Erlang/OTP | **28+** | Elixir runtime |
| PostgreSQL | **16+** | Primary data store |
| Rust | **stable (1.80+)** | CLI |
| OpenTofu *(optional)* | **1.8+** | Required only for `obercloud init` against a real provider; not needed for local dev |

The repo includes a `.tool-versions` file pinning Elixir and Erlang. If you use [`mise`](https://mise.jdx.dev/) or [`asdf`](https://asdf-vm.com/), the right versions are picked up automatically:

```bash
mise install   # or: asdf install
```

PostgreSQL must be running and accessible. On most Linux systems:

```bash
sudo systemctl start postgresql
```

The default config expects `postgres` / `postgres` on `localhost:5432`. If that doesn't match your local setup, edit `server/config/dev.exs` and `server/config/test.exs`.

### Clone and bootstrap the repo

```bash
git clone https://github.com/<your-org>/obercloud.git
cd obercloud
```

Install dependencies, create the database, and run migrations:

```bash
./run_mix_in_server deps.get
./run_mix_in_server ecto.create
./run_mix_in_server ecto.migrate
```

The `./run_mix_in_server` helper just does `cd server && mix "$@"`. If you'd rather not use it, run the equivalent commands inside the `server/` directory.

### Run the server

```bash
./run_mix_in_server phx.server
```

The server boots on **<http://localhost:4000>**.

- **<http://localhost:4000/sign-in>** — sign-in / register page (AshAuthentication password strategy)
- **<http://localhost:4000/>** — dashboard (requires login, shows org/project/node counts)
- **<http://localhost:4000/orgs>**, **/projects**, **/nodes**, **/api_keys** — listing pages
- **<http://localhost:4000/api/...>** — REST API (Bearer auth required, see below)

Stop with `Ctrl+C` twice.

### Build the CLI

```bash
cd cli
cargo build --release
```

The binary lands at `cli/target/release/obercloud`. Either copy it onto your `PATH` or use it directly:

```bash
./cli/target/release/obercloud --help
```

Common subcommands:

```
obercloud context add <name> <url>     # register a server (e.g. http://localhost:4000)
obercloud context use <name>           # switch active server
obercloud auth login                   # sign in (email + password); stores a bearer token

obercloud orgs list / create <name> <slug> / delete <id>
obercloud projects list / create <name> <slug> <org-id> / delete <id>
obercloud nodes list
obercloud apikeys list / create <name> <org-id> [role] / revoke <id>

obercloud init                         # bootstrap a real Hetzner installation
obercloud destroy                      # tear it down
obercloud upgrade                      # upgrade an existing installation
```

Config is persisted at **`~/.config/obercloud/config.toml`**.

### Smoke test: sign up, create an org, hit the API

1. **Register a user** — open <http://localhost:4000/register> in your browser, sign up with an email and password.

2. **Create an organization via the web UI.** *(P0 caveat: the LiveView pages are read-only — see "What works" in the project README. For now, create the org via SQL or via the iex shell:)*

   ```bash
   ./run_mix_in_server -- run -e '
   {:ok, org} = Ash.create(OberCloud.Accounts.Org, %{name: "My Org", slug: "my-org"}, authorize?: false)
   {:ok, [user]} = Ash.read(OberCloud.Accounts.User, authorize?: false)
   {:ok, _} = Ash.create(OberCloud.Accounts.Membership, %{
     user_id: user.id, org_id: org.id, role: "org:owner"
   }, authorize?: false)
   {:ok, %{plaintext: pt}} = OberCloud.Auth.ApiKey.create_with_plaintext(%{
     name: "local-dev", org_id: org.id, role: "org:admin"
   })
   IO.puts("\\nAPI KEY (save this): #{pt}\\n")
   '
   ```

   Copy the `obk_...` API key it prints. **You will not be able to see it again.**

3. **Use it from the CLI:**

   ```bash
   obercloud context add local http://localhost:4000
   ```

   Edit `~/.config/obercloud/config.toml` and paste the API key into the `api_key = "..."` field for the `local` context. Then:

   ```bash
   obercloud orgs list
   obercloud projects create "production" "production" <org-id>
   obercloud projects list
   ```

4. **Or directly via curl:**

   ```bash
   curl -H "Authorization: Bearer obk_..." \
        -H "Accept: application/vnd.api+json" \
        http://localhost:4000/api/orgs
   ```

### Running the test suites

```bash
./run_mix_in_server test         # Elixir/Phoenix tests (47 tests in P0)
cd cli && cargo test             # Rust CLI tests
```

Both should be green on a fresh clone.

---

## 2. Production bootstrap on Hetzner

### Production caveats

⚠️ **Pre-alpha.** The `obercloud init` flow is implemented and will:
- Provision Hetzner VM(s) via OpenTofu
- Install PostgreSQL + Docker via cloud-init
- Try to start the OberCloud container from `ghcr.io/obercloud/obercloud:latest`

**However**, the container image at `ghcr.io/obercloud/obercloud:latest` **does not exist yet** — publishing the official OberCloud release container is on the P1 roadmap. Until then, `obercloud init` is useful for testing the bootstrap mechanics on Hetzner but the resulting VMs won't run a working control plane.

For now, use [Local development](#1-local-development) to actually exercise OberCloud.

### Bootstrap flow (when the image is published)

Prerequisites on your local machine:
- The `obercloud` binary on `PATH`
- The `tofu` binary on `PATH` ([install OpenTofu](https://opentofu.org/docs/intro/install/))
- An SSH keypair at `~/.ssh/id_ed25519` (or `~/.ssh/id_rsa`) — its public key gets installed on the VMs
- A [Hetzner Cloud project token](https://docs.hetzner.com/cloud/api/getting-started/generating-api-token/) with read+write scope

Run:

```bash
obercloud init                 # interactive: prompts for token, region, node count
# or non-interactively:
obercloud init --token hcloud_xxx --region nbg1 --nodes 1
```

What happens:
1. CLI generates an HCL config in a temp dir (single-node or 3-node depending on `--nodes`)
2. Runs `tofu init` and `tofu apply` against your Hetzner project
3. Cloud-init on each VM installs Docker + PostgreSQL and starts the OberCloud container
4. CLI polls `http://<ip>/health` until the control plane is up
5. CLI saves the new server as the `default` context in `~/.config/obercloud/config.toml`
6. Prints the URL and admin password

After bootstrap, use the CLI as you would against a local server.

To tear it down:

```bash
obercloud destroy
```

---

## 3. Configuration reference

### Server (`server/config/runtime.exs`)

These are read at startup. Defaults are dev-only — **set real values in production via env vars.**

| Variable | Default | Purpose |
|---|---|---|
| `DATABASE_URL` | `postgres://postgres:postgres@localhost/obercloud_dev` | PostgreSQL connection |
| `SECRET_KEY_BASE` | random per-boot in dev | Phoenix session/CSRF signing |
| `TOKEN_SIGNING_SECRET` | hard-coded dev string | AshAuthentication JWT signing |
| `CREDENTIAL_ENCRYPTION_KEY` | hard-coded dev string | AES-256-GCM key (must be 32 bytes, base64 encoded) for encrypting cloud provider tokens at rest |
| `OBERCLOUD_TOFU_BIN` | `tofu` (production), `echo` (test) | Path to OpenTofu binary used by the reconciler |
| `PHX_HOST` | `localhost` | Hostname for URL generation |
| `PORT` | `4000` | HTTP listen port |

To generate a 32-byte encryption key:

```bash
head -c 32 /dev/urandom | base64
```

### CLI (`~/.config/obercloud/config.toml`)

Created automatically by `obercloud context add` and `obercloud init`. Manual edits are fine.

```toml
active_context = "local"

[contexts.local]
url = "http://localhost:4000"
api_key = "obk_..."

[contexts.prod]
url = "https://obercloud.mycompany.com"
api_key = "obk_..."
```

Switch contexts with `obercloud context use <name>`.

---

## 4. Troubleshooting

### `mix ecto.create` fails with "FATAL: role 'postgres' does not exist"

PostgreSQL is running but the default `postgres` role isn't set up. Either create it:

```bash
sudo -u postgres createuser -s postgres
```

…or update the `username` / `password` fields in `server/config/dev.exs` and `server/config/test.exs` to match your local Postgres setup.

### Server boots but `/sign-in` is blank or 500

Compile errors in the AshAuthentication.Phoenix routes can manifest at runtime. Recompile with warnings:

```bash
./run_mix_in_server compile --force --warnings-as-errors
```

### CLI returns "no active context"

You haven't registered a server yet. Run:

```bash
obercloud context add local http://localhost:4000
obercloud context use local
```

### CLI returns 401 Unauthorized

Either you haven't logged in (`obercloud auth login`), or the bearer token in `~/.config/obercloud/config.toml` is invalid/revoked. Generate a fresh API key (see the [smoke test](#smoke-test-sign-up-create-an-org-hit-the-api) for how) and paste it into the config file.

### `mise` says elixir/erlang are installed but `mix` complains about a wrong version

The mise shim cache can get stale. Refresh:

```bash
mise reshim
hash -r
```

### `obercloud init` fails with "tofu not found"

Install OpenTofu: <https://opentofu.org/docs/intro/install/>. The bootstrap explicitly uses OpenTofu (an open-source Terraform fork) — HashiCorp Terraform should also work but isn't tested.

### Tests fail with "module Oban.Migrations is not loaded"

Run pending migrations first:

```bash
./run_mix_in_server ecto.migrate
```

---

## Where to next?

- Read the **[design spec](superpowers/specs/2026-04-30-obercloud-p0-control-plane-design.md)** for the architecture overview
- Read the **[implementation plan](superpowers/plans/2026-04-30-obercloud-p0-control-plane.md)** for the task-by-task breakdown
- File issues at <https://github.com/your-org/obercloud/issues>
