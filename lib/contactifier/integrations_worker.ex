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
    integration
    |> ContactProvider.delete_integration()
    |> maybe_return_error()
  end

  def delete_local_integration(_, integration) do
    integration
    |> Integrations.delete_integration()
    |> maybe_return_error()
  end

  def delete_integration_circuit_breaker(error, _, integration) do
    Logger.error("Error deleting integration with id #{integration.id} due to #{inspect(error)}")
    {:abort, error}
  end

  defp maybe_return_error({:ok, _}), do: {:ok, nil}
  defp maybe_return_error({:error, :not_found}), do: {:ok, nil}
  defp maybe_return_error({:error, %{error: %{type: "grant.not_found"}}}), do: {:ok, nil}
  defp maybe_return_error({:error, _error} = res), do: res
end
