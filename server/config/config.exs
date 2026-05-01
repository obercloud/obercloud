# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

# Configure Mix tasks and generators
config :obercloud,
  namespace: OberCloud,
  ecto_repos: [OberCloud.Repo]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :obercloud, OberCloud.Mailer, adapter: Swoosh.Adapters.Local

config :obercloud_web,
  namespace: OberCloudWeb,
  ecto_repos: [OberCloud.Repo],
  generators: [context_app: :obercloud]

# Configures the endpoint
config :obercloud_web, OberCloudWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: OberCloudWeb.ErrorHTML, json: OberCloudWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: OberCloud.PubSub,
  live_view: [signing_salt: "5CKN/qhZ"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  obercloud_web: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../apps/obercloud_web/assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  obercloud_web: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("../apps/obercloud_web", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Ash framework domains and defaults
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

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
