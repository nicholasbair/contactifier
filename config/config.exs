# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :contactifier,
  ecto_repos: [Contactifier.Repo],
  generators: [binary_id: true]

# Configures the endpoint
config :contactifier, ContactifierWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: ContactifierWeb.ErrorHTML, json: ContactifierWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Contactifier.PubSub,
  live_view: [signing_salt: "dVd43VHE"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :contactifier, Contactifier.Mailer, adapter: Swoosh.Adapters.Local

config :contactifier, Oban,
  repo: Contactifier.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 300},
    {Oban.Plugins.Cron,
     crontab: [
        {"@daily", Contactifier.Integrations.Worker, args: %{"task" => "check_stale_integrations"}},
        {"@daily", Contactifier.Contacts.Worker, args: %{"task" => "check_soft_deleted_contacts"}},
        {"@daily", Contactifier.Messages.Worker, args: %{"task" => "start_incremental_sync"}}
     ]}
  ],
  queues: [messages: 2, contacts: 2, integrations: 1]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.2.7",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
