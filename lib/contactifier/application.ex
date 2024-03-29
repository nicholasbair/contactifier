defmodule Contactifier.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      ContactifierWeb.Telemetry,
      # Start the Ecto repository
      Contactifier.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Contactifier.PubSub},
      # Start Finch
      {Finch, name: Contactifier.Finch},
      # Start the Endpoint (http/https)
      ContactifierWeb.Endpoint,
      {Oban, Application.fetch_env!(:contactifier, Oban)},
      {Contactifier.Pipeline, []}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Contactifier.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ContactifierWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
