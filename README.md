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
