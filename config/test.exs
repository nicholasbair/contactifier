import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

config :contactifier, Oban, testing: :inline

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :contactifier, Contactifier.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "contactifier_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :contactifier, ContactifierWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "4IDrjcypIAZpOxgBKw7G2uDzL7IE2M63JBYjMiyGZwWVeMa0ZqJpF/YD8YUFhvLp",
  server: false

# In test we don't send emails.
config :contactifier, Contactifier.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
