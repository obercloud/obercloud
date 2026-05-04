# OberCloud command runner — uses https://github.com/casey/just
# Install with `cargo install just`, `brew install just`, or `mise use just`.
#
# `just` (no args) lists all recipes.
# Recipes use `cd <subdir> && <command>` so each one runs in the right
# directory regardless of where you invoke `just` from.

set shell := ["bash", "-cu"]

# Show all recipes
default:
    @just --list --unsorted

# ─────────────────────────────────────────────────────────────────────
# Top-level: do the right thing for both Elixir and Rust at once
# ─────────────────────────────────────────────────────────────────────

# Install deps + create DB + migrate (run once after cloning)
setup: deps db-setup

# Fetch deps for both server and CLI
deps: mix-deps cargo-fetch

# Run all tests (Elixir + Rust + Vue)
test: mix-test cargo-test vue-test

# Compile / build everything
build: mix-compile cargo-build

# Format both codebases
format: mix-format cargo-fmt

# Clean build artifacts in both
clean: mix-clean cargo-clean

# Everything CI runs: deps, db, tests, lint, build
ci: deps db-setup mix-test cargo-test cargo-clippy mix-compile vue-test vue-typecheck

# ─────────────────────────────────────────────────────────────────────
# Server (Elixir / Phoenix umbrella)
# ─────────────────────────────────────────────────────────────────────

# Boot the Phoenix dev server at http://localhost:4000
server:
    cd server && mix phx.server

# Open an iex shell with the server loaded
iex:
    cd server && iex -S mix

# Compile the umbrella
mix-compile:
    cd server && mix compile

# Fetch Elixir/Hex dependencies
mix-deps:
    cd server && mix deps.get

# Run the Elixir test suite
mix-test *args:
    cd server && mix test {{args}}

# Format Elixir source
mix-format:
    cd server && mix format

# Clean Elixir build artifacts
mix-clean:
    cd server && mix clean

# ─────────────────────────────────────────────────────────────────────
# Database (Ecto)
# ─────────────────────────────────────────────────────────────────────

# Create the dev database and run migrations (idempotent)
db-setup: db-create db-migrate

# Create the dev database
db-create:
    cd server && mix ecto.create

# Run pending migrations
db-migrate:
    cd server && mix ecto.migrate

# Drop, recreate, and migrate the dev database (destructive)
db-reset:
    cd server && mix ecto.reset

# Rollback the last N migrations (default 1)
db-rollback steps='1':
    cd server && mix ecto.rollback --step {{steps}}

# Seed an admin user, org, membership, and API key into the dev DB
seed:
    cd server && mix run ../bootstrap.exs

# ─────────────────────────────────────────────────────────────────────
# CLI (Rust)
# ─────────────────────────────────────────────────────────────────────

# Build the CLI in debug mode
cargo-build:
    cd cli && cargo build

# Build the CLI in release mode (optimized; output at cli/target/release/obercloud)
cargo-release:
    cd cli && cargo build --release

# Run the Rust test suite
cargo-test *args:
    cd cli && cargo test {{args}}

# Format Rust source
cargo-fmt:
    cd cli && cargo fmt

# Run clippy with -D warnings (matches CI)
cargo-clippy:
    cd cli && cargo clippy --all-targets -- -D warnings

# Fetch crate dependencies
cargo-fetch:
    cd cli && cargo fetch

# Clean Rust build artifacts
cargo-clean:
    cd cli && cargo clean

# Run the obercloud CLI with arguments. Example: `just cli orgs list`
cli *args:
    cd cli && cargo run --quiet -- {{args}}

# ─────────────────────────────────────────────────────────────────────
# Web assets (Vue components + Vitest)
# ─────────────────────────────────────────────────────────────────────

# Install npm deps for the web assets (Vitest + Vue + test libs)
vue-deps:
    cd server/apps/obercloud_web/assets && npm install

# Run the Vue component test suite (Vitest)
vue-test:
    cd server/apps/obercloud_web/assets && npm test

# Run Vue component tests in watch mode
vue-test-watch:
    cd server/apps/obercloud_web/assets && npm run test:watch

# Type-check the TypeScript + .vue files
vue-typecheck:
    cd server/apps/obercloud_web/assets && npm run typecheck
