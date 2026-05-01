# OberCloud — P0: Control Plane Bootstrap
**Date:** 2026-04-30
**Status:** Approved

---

## 1. Overview

OberCloud is an open-source platform that provides managed infrastructure services on top of commodity cloud providers (Hetzner, DigitalOcean, and others). It gives indie developers and small companies a self-hosted alternative to platforms like Fly.io or Heroku, with full control over their infrastructure.

**P0 delivers the empty platform:** OberCloud running on Hetzner, accessible via browser and REST API, ready to accept resource provisioning in P1+.

**P0 does NOT provision customer resources** — no VMs, networks, databases, or managed services. That begins in P1.

### What a user can do after P0

1. Run `obercloud init` → answer prompts (Hetzner API token, region, node count) → control plane VMs created, OberCloud installed, URL + admin credentials printed
2. Log into the web UI → create organizations, invite users, assign roles
3. Create API keys with RBAC policies
4. Use the REST API with those keys
5. Run `obercloud` CLI commands against the running server from their local machine
6. Scale the control plane from 1 → 3 nodes via UI (reconciler handles expansion)

---

## 2. Deployment Topology

Single-node and multi-node are both first-class deployments — neither is a dev-only mode.

### Single-node (default for indie devs)
- 1 Hetzner VM running: Phoenix app + PostgreSQL + OpenTofu
- Control plane shares the node with customer workloads (P1+)
- No HA — acceptable trade-off for cost-sensitive deployments

### Multi-node (recommended for production)
- 3 Hetzner VMs
- All 3 Elixir nodes active (`libcluster` + `Horde` for distributed coordination)
- PostgreSQL: 1 primary + 2 hot standbys
- Oban peer mode: only one node runs a given reconciliation job at a time
- Control plane can coexist with customer workloads on the same nodes

Node count is chosen at `obercloud init` time. Expansion (1 → 3 nodes) is done via UI after initial setup — the reconciler handles it.

---

## 3. Architecture

```
┌─────────────────────────────────────────────────────┐
│  Developer / Admin machine                           │
│  obercloud CLI (Rust binary)                         │
│  ├── Bootstrap mode: init / destroy / upgrade        │
│  │   └── Generates + applies OpenTofu configs        │
│  └── Admin mode: orgs / users / projects / nodes    │
│      └── HTTPS → OberCloud REST API                 │
└────────────────────────┬────────────────────────────┘
                         │ HTTPS (TLS)
┌────────────────────────▼────────────────────────────┐
│  1–N Hetzner VMs (control plane + workloads)         │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │  OberCloud Phoenix App (Elixir/OTP)          │   │
│  │  ├── Web: LiveView + LiveVue (admin UI)      │   │
│  │  ├── API: REST via AshJsonApi (RBAC)         │   │
│  │  ├── Core contexts:                          │   │
│  │  │   ├── Accounts (orgs, users, memberships) │   │
│  │  │   ├── Auth (sessions, API keys, RBAC)     │   │
│  │  │   ├── Projects                            │   │
│  │  │   └── ControlPlane (node management)     │   │
│  │  └── Reconciler (Oban + GenServer)           │   │
│  │      └── Desired state → OpenTofu → Hetzner │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  PostgreSQL (primary [+ 2 standbys in 3-node mode]) │
│  OpenTofu state stored in PostgreSQL pg backend     │
└─────────────────────────────────────────────────────┘
```

### Technology Stack

| Layer | Technology | Rationale |
|---|---|---|
| Language | Elixir (primary), Rust (CLI) | OTP for long-running orchestration; Rust for distributable binary |
| Web framework | Phoenix + LiveView + LiveVue | Real-time infra dashboards; Vue for complex interactive components |
| Data layer | Ash Framework + AshPostgres | Declarative resources, built-in policy engine, auto-generated REST API |
| Authorization | Ash.Policy.Authorizer | RBAC with resource-scoped permissions, extensible |
| REST API | AshJsonApi | OpenAPI spec generated automatically |
| Job queue | Oban (PostgreSQL-backed) | Persistent, retriable reconciliation jobs; peer mode for 3-node |
| Distributed Elixir | libcluster + Horde | Node discovery, distributed process registry |
| IaC engine | OpenTofu (MPL 2.0) | AGPL-safe alternative to Terraform; full provider ecosystem |
| Frontend tests | Vitest + Vue Test Utils | Component isolation testing |
| Backend tests | ExUnit | Unit + integration; provider HTTP mocked |
| License | AGPL-3.0 | Modifications to network-served software must be open-sourced |

---

## 4. Data Model

All resources are provider-agnostic. Provider-specific details live in `provider` + `provider_resource_id` + `provider_metadata` — adding a new provider requires zero schema changes.

### Core Tables

```
organizations
  id uuid PK
  name text NOT NULL
  slug text UNIQUE NOT NULL
  created_at timestamptz

users
  id uuid PK
  email text UNIQUE NOT NULL
  hashed_password text NOT NULL
  name text NOT NULL
  created_at timestamptz

memberships
  id uuid PK
  user_id uuid FK users
  org_id uuid FK organizations
  role text NOT NULL  -- org:owner | org:admin | org:member | org:viewer
  UNIQUE (user_id, org_id)

projects
  id uuid PK
  org_id uuid FK organizations
  name text NOT NULL
  slug text NOT NULL
  created_at timestamptz
  UNIQUE (org_id, slug)

api_keys
  id uuid PK
  org_id uuid FK organizations
  user_id uuid FK users (nullable — org-level keys)
  name text NOT NULL
  key_prefix text NOT NULL     -- displayed: "obk_abc123..."
  key_hash text NOT NULL       -- bcrypt hash, never stored plaintext
  role text NOT NULL           -- maps to Ash policy role
  expires_at timestamptz       -- nullable = never expires
  last_used_at timestamptz
  revoked_at timestamptz
  created_at timestamptz

nodes
  id uuid PK
  provider text NOT NULL              -- "hetzner" | "digitalocean" | ...
  provider_resource_id text           -- provider's server ID (nullable until provisioned)
  provider_metadata jsonb             -- region, server_type, datacenter, etc.
  ip_address inet
  role text NOT NULL                  -- primary | standby | worker
  status text NOT NULL                -- provisioning | ready | degraded | decommissioned
  joined_at timestamptz
  created_at timestamptz

provider_credentials
  id uuid PK
  org_id uuid FK organizations
  provider text NOT NULL
  credentials_enc bytea NOT NULL      -- AES-256-GCM encrypted jsonb
  created_at timestamptz

desired_state
  id uuid PK
  org_id uuid FK organizations
  project_id uuid FK projects (nullable — some resources are org-level)
  resource_type text NOT NULL
  resource_id uuid NOT NULL
  spec jsonb NOT NULL                 -- desired configuration
  reconcile_status text NOT NULL      -- pending | reconciling | ready | failed | drifted
  reconciled_at timestamptz
  error text                          -- last reconcile error if failed

opentofu_state
  id uuid PK
  workspace_key text UNIQUE NOT NULL  -- e.g. "control-plane" | "org/abc/project/xyz"
  state_json jsonb NOT NULL
  locked_by text                      -- node identity holding the lock
  locked_at timestamptz
  updated_at timestamptz
```

### RBAC Model

Authorization is implemented via `Ash.Policy.Authorizer`. Roles are:

| Role | Scope | Capabilities |
|---|---|---|
| `system:owner` | Installation | Full control over everything including nodes |
| `org:owner` | Organization | Full control within their org |
| `org:admin` | Organization | Manage users, projects, API keys |
| `org:member` | Organization | Work within projects |
| `org:viewer` | Organization | Read-only |

Ash policies are defined in code (version-controlled). Resource-scoped permissions (e.g., `projects:write` on project `xyz` only) are supported in the policy definitions — they are not wired to a UI in P0 but the policy engine handles them.

API keys carry a role. The Ash policy evaluator receives the key's role as the actor's role when evaluating requests.

---

## 5. Rust CLI

### Bootstrap Mode (runs before the server exists)

```
obercloud init          # interactive wizard → OpenTofu bootstrap
obercloud destroy       # tears down control plane VMs
obercloud upgrade       # upgrades OberCloud on existing nodes
```

**`obercloud init` flow:**
1. Prompt: provider (Hetzner in P0), API token, region, node count (default: 1, suggests 3)
2. Validate credentials against Hetzner API
3. Generate OpenTofu HCL configs
4. Run `tofu init` + `tofu apply`
5. Wait for OberCloud web app health check to pass
6. Create `system:owner` user, print URL + credentials
7. Write new server as active context to `~/.config/obercloud/config.toml`

### Admin Mode (talks to running server)

```
obercloud context add <name> <url>
obercloud context use <name>
obercloud auth login

obercloud orgs list / create / delete
obercloud users invite / list / remove
obercloud projects list / create / delete
obercloud nodes list / status / add / drain
obercloud apikeys create / list / revoke
```

### Config File (`~/.config/obercloud/config.toml`)

```toml
active_context = "prod"

[contexts.prod]
url = "https://cloud.mycompany.com"
api_key = "obk_..."

[contexts.staging]
url = "https://staging.mycompany.com"
api_key = "obk_..."
```

Supports multiple server contexts — an indie developer managing multiple client installations switches with `obercloud context use <name>`.

---

## 6. Phoenix Application Structure

```
obercloud/
├── apps/
│   ├── obercloud_core/
│   │   ├── lib/
│   │   │   ├── accounts/            # Ash resources: Org, User, Membership
│   │   │   ├── auth/                # Ash resources: ApiKey; session logic
│   │   │   ├── projects/            # Ash resource: Project
│   │   │   ├── control_plane/       # Ash resource: Node; cluster health GenServer
│   │   │   ├── providers/
│   │   │   │   ├── provider.ex      # @behaviour (provision/deprovision/status callbacks)
│   │   │   │   └── hetzner/         # Hetzner HTTP client + resource mapping
│   │   │   └── reconciler/          # Oban workers + drift detector cron
│   │   └── test/
│   │
│   └── obercloud_web/
│       ├── lib/
│       │   ├── live/                # LiveView pages (embed LiveVue components)
│       │   ├── api/                 # AshJsonApi router + custom plugs
│       │   ├── plugs/               # Auth plug (session + API key)
│       │   └── components/          # Shared LiveComponent + Vue bridge components
│       └── test/
│
├── assets/
│   ├── vue/                         # Vue 3 components (via LiveVue)
│   ├── js/                          # LiveVue entrypoint, app.js
│   └── css/                         # Tailwind CSS
│
├── priv/repo/migrations/
│
└── test/assets/vue/                 # Vitest component tests
```

### Context Rules

- `obercloud_core` has zero HTTP or LiveView dependencies — pure business logic
- `providers/provider.ex` is an Elixir `@behaviour` — adding DigitalOcean means implementing the same callbacks in `providers/digitalocean/`, nothing else changes
- Ash resources live in core contexts; AshJsonApi wires them to HTTP in the web app
- Reconciler is plain OTP (GenServer + Oban) — no Ash involvement

---

## 7. Reconciliation Engine

The reconciler is the core of OberCloud — it watches desired state and drives OpenTofu to make reality match it.

### Reconcile Flow

```
User action (UI or API)
  → Ash resource update (writes spec to desired_state, status: pending)
  → Oban job enqueued: ReconcileWorker
  → ReconcileWorker:
      1. Lock opentofu_state workspace row
      2. Load desired spec from desired_state
      3. Render OpenTofu HCL (Elixir → HCL string)
      4. Write HCL to temp workspace dir
      5. Run `tofu plan` → parse output
      6. If changes: run `tofu apply`
      7. Parse outputs → write provider_resource_id, IPs back to DB
      8. Update desired_state.reconcile_status → ready | failed
      9. Broadcast via Phoenix.PubSub → LiveView updates in real time
```

### Drift Detection

An Oban cron job runs every 5 minutes:
1. For each resource: compare `desired_state.spec` against OpenTofu state
2. If drift detected: update `reconcile_status → drifted`, enqueue `ReconcileWorker`
3. Surface drift warning in UI (banner on affected resource)

### OpenTofu State Backend

OpenTofu state is stored in the `opentofu_state` PostgreSQL table — not in local files or S3. This works identically in single-node and 3-node deployments. The `locked_by` / `locked_at` columns implement the OpenTofu state lock protocol.

---

## 8. Testing Strategy

### Backend (ExUnit)

```
test/obercloud_core/
  accounts_test.exs              # Org/user/membership CRUD + Ash policy enforcement
  auth_test.exs                  # API key creation, hashing, RBAC evaluation
  projects_test.exs              # Project CRUD, org scoping
  providers/hetzner_test.exs     # Hetzner adapter (HTTP mocked via Req.Test)
  reconciler/reconcile_worker_test.exs  # Reconcile job (tofu binary mocked)
  reconciler/drift_detector_test.exs

test/obercloud_web/
  api/orgs_controller_test.exs        # REST endpoints via AshJsonApi
  api/projects_controller_test.exs
  live/dashboard_live_test.exs        # LiveView page tests
  live/nodes_live_test.exs
  live/orgs_live_test.exs
  plugs/auth_plug_test.exs            # API key + session auth
```

**Rules:**
- Hetzner HTTP calls always mocked — tests never hit real provider APIs
- OpenTofu binary replaced by a configurable mock wrapper in test env
- Ash policies tested directly: assert actor can/cannot perform action on resource
- LiveView tests verify real-time PubSub updates (e.g. resource status change → UI reflects it)

### Frontend (Vitest + Vue Test Utils)

```
test/assets/vue/
  OrgSwitcher.test.ts
  NodeStatusBadge.test.ts
  ApiKeyForm.test.ts
  ResourceTable.test.ts
```

**Rules:**
- Vue components tested in isolation
- LiveVue socket events mocked
- No browser E2E tests in P0 (Playwright deferred to P2+)

### CI Pipeline

```
mix test                   # ExUnit
mix test --cover           # Coverage report
mix credo                  # Elixir linting
mix dialyzer               # Type checking
npm run test               # Vitest
npm run lint               # ESLint + TypeScript
cargo test                 # Rust CLI unit tests
cargo clippy               # Rust linting
```

---

## 9. Open Source & Licensing

**License: AGPL-3.0**

Any party offering OberCloud as a network service must open-source their modifications under AGPL. Self-hosting, modifying, and internal use are freely allowed. Indie developers and companies running their own installation are unaffected.

**Enterprise commercial license** available separately for companies requiring a non-copyleft option.

---

## 10. Out of Scope for P0

The following are explicitly deferred to later phases:

- VM / resource provisioning for customers (P1)
- WireGuard network overlay (P2)
- Any managed services: PostgreSQL, load balancer, DNS, S3, RabbitMQ, Kafka, etc. (P3–P6)
- App deployment / Docker image push (P8)
- Auto-scaling (P9)
- Lambda-style job execution (P10)
- Tailscale integration (P11)
- Reseller / sub-account UI (P12)
- Bounce AI Ops (P13)
- Terraform provider plugin (P14)
- DigitalOcean provider adapter (P1)
- Pricing transparency UI (P15)
- Browser E2E tests (P2+)
- Rust NIFs (added when WireGuard networking requires them, P2)

---

## 11. Open Questions (Resolved)

| Question | Decision |
|---|---|
| Cluster topology | Single-node (default) or 3-node (recommended); both first-class |
| Bootstrap approach | CLI-first (Rust binary), internals structured for plain Terraform module later |
| Provider in P0 | Hetzner only |
| UI framework | Phoenix LiveView + LiveVue (Vue 3) |
| API authorization | Ash.Policy.Authorizer (RBAC with resource-scoped permission support) |
| Multi-tenancy | Multi-org from day one; orgs are core, not a reseller add-on |
| IaC engine | OpenTofu (MPL 2.0, AGPL-safe) |
| Ash Framework | Used selectively: AshPostgres + Ash.Policy + AshJsonApi; not for reconciler/providers |
| License | AGPL-3.0 with commercial enterprise license |
