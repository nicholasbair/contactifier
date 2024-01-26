defmodule Contactifier.Integrations.Worker do
  require Logger

  alias Contactifier.Integrations
  alias Contactifier.Integrations.ContactProvider

  use Oban.Worker,
    queue: :integrations,
    max_attempts: 3

  @one_week 7 * 60 * 60 * 24

  @impl true
  def perform(%{args: %{"task" => "check_stale_integrations"}}) do
    Logger.info("Checking for stale integrations")

    Integrations.list_invalid_integrations()
    |> Enum.each(&check_integration/1)

    :ok
  end

  def check_integration(integration) do
    with true <- stale?(integration) do
      Sage.new()
      |> Sage.run(:delete_on_provider, &delete_provider_integration/2, &delete_integration_circuit_breaker/3)
      |> Sage.run(:delete_on_db, &delete_local_integration/2, &delete_integration_circuit_breaker/3)
      |> Sage.execute(integration)
    end
  end

  def stale?(integration) do
    DateTime.diff(DateTime.utc_now(), integration.invalid_since) > @one_week
  end

  def delete_provider_integration(_, integration) do
    case ContactProvider.delete_integration(integration.vendor_id) do
      {:ok, _} ->
        :ok

      {:error, :not_found} ->
        :ok

      {:error, error} ->
        {:error, error}
    end
  end

  def delete_local_integration(_, integration) do
    Integrations.delete_integration(integration.id)
  end

  def delete_integration_circuit_breaker(error, _, integration) do
    Logger.error("Error deleting integration with id #{integration.id} due to #{inspect(error)}")
    :abort
  end
end
