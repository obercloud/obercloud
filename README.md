# OberCloud

Open-source platform for managed infrastructure on commodity cloud providers (Hetzner, DigitalOcean, ...).

**Status:** Pre-alpha — P0 in development.

## What it is

OberCloud lets indie developers and small companies self-host a Fly.io / Heroku-style platform on cheap VMs. After installation:

- Multi-tenant from day one (organizations isolate workloads per customer)
- Web UI + REST API + Rust CLI for management
- AGPL-3.0 licensed; commercial enterprise license available

## Quickstart

```bash
git clone https://github.com/<your-org>/obercloud.git
cd obercloud

./run_mix_in_server deps.get
./run_mix_in_server ecto.create
./run_mix_in_server ecto.migrate
./run_mix_in_server phx.server
# server is now at http://localhost:4000

cd cli && cargo build --release
./target/release/obercloud --help
```

Full walkthrough including production bootstrap on Hetzner: **[docs/INSTALL.md](docs/INSTALL.md)**.

## What works in P0

- Phoenix umbrella with Ash resources for orgs, users, memberships, projects, control plane nodes, provider credentials, API keys, and reconciliation state
- RBAC enforced via Ash policies (system:owner / org:owner / org:admin / org:member / org:viewer)
- REST API at `/api/*` (AshJsonApi) with Bearer-token authentication
- Web sign-in/sign-out via AshAuthentication.Phoenix; read-only LiveView listing pages for orgs/projects/nodes/api_keys
- Reconciler loop (Oban): renders desired state to OpenTofu HCL, runs `tofu apply`, broadcasts updates via Phoenix.PubSub
- DriftDetector cron worker (every 5 minutes)
- Hetzner Cloud provider adapter (validate credentials, list regions/server types)
- Rust CLI (`obercloud`) with subcommands for context management, auth, orgs, projects, nodes, api keys, and Hetzner bootstrap
- GitHub Actions CI for both Elixir and Rust

## What's not in P0

- Vue/LiveVue components for the UI (deferred)
- Write actions on LiveView pages (use the REST API or CLI to create/update)
- Published `ghcr.io/obercloud/obercloud` container — `obercloud init` provisions Hetzner VMs but the resulting cloud-init can't pull a release image yet
- DigitalOcean provider, network overlay, managed services, app deployment — all on the P1+ roadmap

## Repository layout

- `server/` — Elixir/Phoenix umbrella (`obercloud` core + `obercloud_web` web app)
- `cli/` — Rust CLI source
- `docs/INSTALL.md` — install + getting started
- `docs/superpowers/specs/` — design specs
- `docs/superpowers/plans/` — implementation plans
- `run_mix_in_server` — small wrapper: `cd server && mix "$@"`

## License

AGPL-3.0. See [LICENSE](LICENSE). Network deployments must open-source their modifications. A commercial enterprise license without the AGPL copyleft is available on request.
