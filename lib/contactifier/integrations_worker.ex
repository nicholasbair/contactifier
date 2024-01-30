defmodule Contactifier.Integrations.Worker do
  @moduledoc """
  Worker to check for stale integrations and delete them.

  - The end user will need to periodically re-authenticate with the provider to continue using the integration.
  - If the end user does not re-authenticate within a week of the integration being invalid, the integration will be considered stale and deleted.
  - If the end user re-authenticates after the integration has been deleted, a new integration will be created.
  - It is important to run this job as Nylas grants are billable even if they are invalid.
  - Typically, an application would have a workflow, UI queues, etc, to notify the end user that they need to re-authenticate.
  """

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
    check_stale_integrations()

    # The job will only retry if an error is raised
    :ok
  end

  def check_stale_integrations() do
    Integrations.list_invalid_integrations()
    |> Enum.filter(&stale?/1)
    |> Enum.each(&check_integration/1)
  end

  # -- Private --

  defp stale?(integration) do
    DateTime.diff(DateTime.utc_now(), integration.invalid_since) > @one_week
  end

  defp check_integration(integration) do
    integration
    |> delete_provider_integration()
    |> delete_local_integration(integration)
  end

  defp delete_provider_integration(integration) do
    integration
    |> ContactProvider.delete_integration()
    |> maybe_return_error()
  end

  defp delete_local_integration(:ok, integration) do
    integration
    |> Integrations.delete_integration()
    |> maybe_return_error()
  end

  # Skip deleting the local integration there was an error deleting the provider integration
  defp delete_local_integration(:skip, _integration), do: :ok

  defp maybe_return_error({:ok, _}), do: :ok
  defp maybe_return_error({:error, %{status: :not_found}}), do: :ok
  defp maybe_return_error({:error, :not_found}), do: :ok
  defp maybe_return_error({:error, error}) do
    Logger.error("Error deleting stale integration: #{inspect(error)}")
    :skip
  end
end
