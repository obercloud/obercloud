# syntax=docker/dockerfile:1
# Multi-stage build for the OberCloud server (Phoenix umbrella).

ARG ELIXIR_VERSION=1.19.2
ARG OTP_VERSION=28.1.1
ARG DEBIAN_VERSION=bookworm-20241016-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

# ---- builder ----
FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y \
 && apt-get install -y --no-install-recommends build-essential git curl ca-certificates \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

ENV MIX_ENV=prod \
    LANG=C.UTF-8

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

# Copy umbrella mix files first for better layer caching
COPY mix.exs mix.lock ./
COPY config config
COPY apps/obercloud/mix.exs apps/obercloud/mix.exs
COPY apps/obercloud_web/mix.exs apps/obercloud_web/mix.exs

RUN mix deps.get --only $MIX_ENV
RUN mix deps.compile

# Now copy the rest of the source
COPY apps apps

# Web assets (esbuild + tailwind)
RUN mix assets.deploy

RUN mix compile
RUN mix release

# ---- runtime ----
FROM ${RUNNER_IMAGE} AS runtime

RUN apt-get update -y \
 && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 locales ca-certificates curl \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
 && locale-gen

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    MIX_ENV=prod \
    PHX_SERVER=true \
    PORT=4000

WORKDIR /app

# Run as a non-root user
RUN useradd --create-home --shell /bin/bash app

COPY --from=builder --chown=app:app /app/_build/prod/rel/obercloud_web ./

USER app

EXPOSE 4000

CMD ["bin/obercloud_web", "start"]
