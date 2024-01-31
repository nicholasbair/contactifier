defmodule Contactifier.Integrations.Worker do
  require Logger

  alias Contactifier.{
    Integrations,
    Integrations.ContactProvider,
    Saga
  }

  use Oban.Worker,
    queue: :integrations,
    max_attempts: 3

  @one_week 7 * 60 * 60 * 24

  @impl Oban.Worker
  def perform(%{args: %{"task" => "check_stale_integrations"}}) do
    Logger.info("Checking for stale integrations")

    Integrations.list_invalid_integrations()
    |> Enum.each(&check_integration/1)

    :ok
  end

  def check_integration(integration) do
    with true <- stale?(integration) do
      Saga.new()
      |> Saga.run(:delete_on_provider, &delete_provider_integration/2, &delete_provider_integration_circuit_breaker/3)
      |> Saga.run(:delete_on_db, &delete_local_integration/2, &delete_local_integration_circuit_breaker/3)
    end
  end

  def stale?(integration) do
    DateTime.diff(DateTime.utc_now(), integration.invalid_since) > @one_week
  end

  def delete_provider_integration(_, integration) do
    ContactProvider.delete_integration(integration.vendor_id)
  end

  def delete_local_integration(_, integration) do
    Integrations.delete_integration(integration.id)
  end

  def delete_provider_integration_circuit_breaker(%{status: :not_found}, _, integration) do
    Logger.info("Error deleting provider integration with id #{integration.id} due to :not_found, proceeding with local deletion")
    :ok
  end

  def delete_provider_integration_circuit_breaker(error, _, integration) do
    Logger.error("Error deleting provider integration with id #{integration.id} due to #{inspect(error)}")
    {:cancel, "cancelling deletion of stale integration with id #{integration.id} due to #{inspect(error)}"}
  end

  def delete_local_integration_circuit_breaker(error, _, integration) do
    Logger.error("Error deleting local integration with id #{integration.id} due to #{inspect(error)}")
    :abort_with_error
  end
end
