# OberCloud — Installation Guide

This guide covers two scenarios:

- **[Local development](#1-local-development)** — running OberCloud on your laptop to try it out, contribute, or evaluate the codebase.
- **[Production bootstrap](#2-production-bootstrap-vultr-or-hetzner)** — provisioning a real OberCloud installation on Vultr or Hetzner via the `obercloud` CLI. *(Pre-alpha — see the [Production caveats](#production-caveats) section before you try this.)*

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
2. [Production bootstrap (Vultr or Hetzner)](#2-production-bootstrap-vultr-or-hetzner)
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
| `just` | **1.50+** | Task runner — every dev command goes through it |
| OpenTofu *(optional)* | **1.8+** | Required only for `obercloud init` against a real provider; not needed for local dev |

If you don't have `just`: `cargo install just`, `brew install just`, or `mise use just@latest` (the repo's `.tool-versions` already pins it for mise users).

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
git clone https://github.com/obercloud/obercloud.git
cd obercloud
```

List every available task:

```bash
just            # equivalent to `just --list`
```

Install dependencies, create the database, and run migrations:

```bash
just setup
```

This is shorthand for `just deps && just db-setup` — it fetches Elixir + Rust deps and creates+migrates the dev database.

### Run the server

```bash
just server
```

The server boots on **<http://localhost:4000>**.

- **<http://localhost:4000/sign-in>** — sign-in / register page (AshAuthentication password strategy)
- **<http://localhost:4000/>** — dashboard (requires login, shows org/project/node counts)
- **<http://localhost:4000/orgs>**, **/projects**, **/nodes**, **/api_keys** — listing pages
- **<http://localhost:4000/api/...>** — REST API (Bearer auth required, see below)

Stop with `Ctrl+C` twice.

### Build the CLI

```bash
just cargo-release
```

The binary lands at `cli/target/release/obercloud`. Either copy it onto your `PATH` or use it directly:

```bash
./cli/target/release/obercloud --help
```

For day-to-day dev you can also drive the CLI without building it explicitly:

```bash
just cli orgs list
just cli context add local http://localhost:4000
```

(`just cli ...` runs the obercloud CLI in debug mode via `cargo run`.)

Common subcommands:

```
obercloud context add <name> <url>     # register a server (e.g. http://localhost:4000)
obercloud context use <name>           # switch active server
obercloud auth login                   # sign in (email + password); stores a bearer token

obercloud orgs list / create <name> <slug> / delete <id>
obercloud projects list / create <name> <slug> <org-id> / delete <id>
obercloud nodes list
obercloud apikeys list / create <name> <org-id> [role] / revoke <id>

obercloud init                         # bootstrap a real installation (vultr default)
obercloud destroy                      # tear it down
obercloud upgrade                      # upgrade an existing installation
```

Config is persisted at **`~/.config/obercloud/config.toml`**.

### Smoke test: bootstrap an admin, then drive it via the CLI

The web UI lets you sign up via <http://localhost:4000/register>, but in P0 the LiveView pages are read-only. So the fastest way to exercise the system end-to-end is a one-shot bootstrap script that creates a user, an org, a membership, and an API key — then use the CLI for everything from there.

1. **Run the bootstrap.** Save the snippet below to `bootstrap.exs` at the project root:

   ```elixir
   # bootstrap.exs
   {:ok, user} =
     OberCloud.Accounts.User
     |> Ash.Changeset.for_create(:register_with_password, %{
       email: "admin@obercloud.local",
       name: "Admin",
       password: "changeme1234",
       password_confirmation: "changeme1234"
     })
     |> Ash.create(authorize?: false)

   {:ok, org} =
     Ash.create(
       OberCloud.Accounts.Org,
       %{name: "My Org", slug: "my-org"},
       authorize?: false
     )

   {:ok, _membership} =
     Ash.create(
       OberCloud.Accounts.Membership,
       %{user_id: user.id, org_id: org.id, role: "org:owner"},
       authorize?: false
     )

   {:ok, %{plaintext: pt}} =
     OberCloud.Auth.ApiKey.create_with_plaintext(%{
       name: "local-dev",
       org_id: org.id,
       role: "org:admin"
     })

   IO.puts("""

   ============================================
     User:    admin@obercloud.local / changeme1234
     Org id:  #{org.id}
     API key: #{pt}
   ============================================
   You will not see the API key again — copy it now.
   """)
   ```

   Run it:

   ```bash
   just seed
   ```

   Copy the `obk_...` API key it prints. **You will not be able to see it again** (only its bcrypt hash is stored).

   Re-running the script will fail on the user/org creation because of the unique-email and unique-slug constraints. To start over:

   ```bash
   just db-reset    # drops + recreates + migrates the dev DB
   just seed
   ```

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
just test            # both Elixir + Rust
just mix-test        # just Elixir
just cargo-test      # just Rust
```

Both should be green on a fresh clone.

---

## 2. Production bootstrap (Vultr or Hetzner)

### Production caveats

⚠️ **Pre-alpha.** The `obercloud init` flow is implemented and will:
- Provision VM(s) on Vultr or Hetzner via OpenTofu
- Install PostgreSQL + Podman via cloud-init
- Start the OberCloud container from `ghcr.io/obercloud/obercloud:latest`

The official `ghcr.io/obercloud/obercloud:latest` image is published by the **`.github/workflows/release.yml`** workflow on every push to `main` and on every `v*` tag. The first push to `main` after the workflow lands will publish the initial image; until then, `obercloud init` will provision VMs but the cloud-init container pull will fail.

### Where does what run, and where does state live?

- **The `obercloud` CLI runs on your local machine.** It does not run on the control plane VMs. It's the tool you use to drive everything else.
- **OpenTofu must be installed locally.** The CLI shells out to `tofu` (the binary needs to be on `PATH`). [Install instructions](https://opentofu.org/docs/intro/install/).
- **OpenTofu state is stored on your local machine** at `~/.config/obercloud/<cluster-name>/terraform.tfstate`, alongside `main.tf`, `cloud_init.yaml`, and `terraform.tfvars`. `terraform.tfvars` contains your provider token in plaintext, so:
  - The directory is created with default permissions — `chmod 700 ~/.config/obercloud` to lock it down.
  - **Back this directory up before tearing down a cluster.** Lose it, and you lose the ability to `obercloud destroy` or `obercloud upgrade` cleanly.
  - A future release will move state into the running OberCloud DB so the CLI doesn't need it locally.

### Prerequisites on your local machine

- The `obercloud` binary on `PATH`
- The `tofu` binary on `PATH`
- An SSH keypair at `~/.ssh/id_ed25519` (or `~/.ssh/id_rsa`) — its public key gets installed on the VMs
- A provider API token:
  - **Vultr** (default) — generate at <https://my.vultr.com/settings/#settingsapi>. Requires "subscription" + "billing read" scopes.
  - **Hetzner** — a [Hetzner Cloud project token](https://docs.hetzner.com/cloud/api/getting-started/generating-api-token/) with read+write scope.

### Run it

Vultr (default — `--provider vultr` is implicit):

```bash
# Interactive — prompts for the Vultr API key, accepts other flags as defaults:
obercloud init

# Non-interactive:
obercloud init \
  --token YOUR_VULTR_API_KEY \
  --region ewr \
  --nodes 1 \
  --server-type vc2-2c-4gb \
  --name acme-prod
```

Hetzner:

```bash
obercloud init \
  --provider hetzner \
  --token YOUR_HETZNER_TOKEN \
  --region nbg1 \
  --server-type cx21 \
  --name acme-prod
```

| Flag | Default (vultr) | Default (hetzner) | Notes |
|---|---|---|---|
| `--provider` | `vultr` | — | `vultr` or `hetzner` |
| `--token` | *(prompt)* | *(prompt)* | Provider API token / key |
| `--region` | `ewr` (New Jersey) | `nbg1` (Nuremberg) | Provider region code. Vultr: `ewr` / `lhr` / `fra` / `nrt` etc. Hetzner: `nbg1` / `fsn1` / `hel1` etc. |
| `--nodes` | `1` | `1` | `1` = indie dev, `3` = HA. No other values supported. |
| `--server-type` | `vc2-2c-4gb` | `cx21` | Vultr: 2 vCPU / 4 GB / $24mo. Hetzner: 2 vCPU / 4 GB / ~€5mo. |
| `--name` | `obercloud` | `obercloud` | Logical name for the cluster. Used as the VM hostname prefix, the CLI context name, and the directory name under `~/.config/obercloud/`. Pick something descriptive (`acme-prod`, `staging`, `client-x`). |

### What happens during `init`

1. CLI renders an HCL config in a temp dir (the right `*_single_node.tf` / `*_multi_node.tf` for your chosen provider).
2. Runs `tofu init` then `tofu apply` against your provider account.
3. The provider provisions the VM(s):
   - **Single-node:** one VM tagged `obercloud`, `control-plane`, `<cluster-name>`.
   - **Multi-node (Vultr):** three VMs + a Vultr VPC2 (`10.42.1.0/24`); the primary is provisioned first, standbys reference its public IP via cloud-init for PG streaming replication. (Vultr's vpc2 doesn't expose deterministic per-instance private IPs at create time the way Hetzner does — replication is still TLS-encrypted by Postgres, just routes via public network for P0.)
   - **Multi-node (Hetzner):** three servers + a Hetzner private network (`10.42.0.0/16`) with deterministic per-node private IPs so PG replication, libcluster, and Horde traffic all stay internal.
4. Cloud-init on each VM installs `podman`, `postgresql-16`, and runs the OberCloud container (`ghcr.io/obercloud/obercloud:latest`) with `--restart unless-stopped` so it survives reboots.
5. CLI polls `http://<primary-ip>/health` until the control plane responds.
6. CLI registers the new server as the `<cluster-name>` context in `~/.config/obercloud/config.toml` and makes it active.
7. Prints the URL and admin password.

### How does the control plane authenticate against the provider for future provisioning?

Cloud-init writes the provider token to `/etc/obercloud/env` on the VM as `OBERCLOUD_BOOTSTRAP_PROVIDER_TOKEN`. **This is a bootstrap-only credential** that lets the control plane do a first reconcile against the provider before an admin POSTs a long-lived credential.

The intended operational flow is:

1. After `obercloud init` finishes, log in as the `system:owner`.
2. POST to `/api/provider_credentials` with the provider token (the API encrypts it at rest with AES-256-GCM using `CREDENTIAL_ENCRYPTION_KEY`). Specify `provider: "vultr"` or `provider: "hetzner"` per credential.
3. Remove `OBERCLOUD_BOOTSTRAP_PROVIDER_TOKEN` from `/etc/obercloud/env` and rebuild the container.

The bootstrap-token UX is rough in P0 — automating step 2 is on the P1 list.

### Why Podman, not Docker?

Podman is rootless by default, daemonless, and a near-drop-in replacement for `docker run`. Less attack surface for a cloud-facing control plane, and one fewer system service to keep running.

### Tear down

```bash
obercloud destroy --name acme-prod    # or just `obercloud destroy` to use the active context
```

This runs `tofu destroy` against the persisted state in `~/.config/obercloud/<name>/`.

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
cd server && mix compile --force --warnings-as-errors
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
just db-migrate
```

---

## Where to next?

- Read the **[design spec](superpowers/specs/2026-04-30-obercloud-p0-control-plane-design.md)** for the architecture overview
- Read the **[implementation plan](superpowers/plans/2026-04-30-obercloud-p0-control-plane.md)** for the task-by-task breakdown
- File issues at <https://github.com/obercloud/obercloud/issues>
