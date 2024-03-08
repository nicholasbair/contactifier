defmodule Contactifier.Messages.Worker do
  require Logger

  import Contactifier.Worker.Util, only: [maybe_cancel_job: 1]

  alias Contactifier.{
    Integrations,
    Integrations.ContactProvider,
    Pipeline,
    Saga
  }

  use Oban.Worker,
    queue: :messages,
    max_attempts: 3

  # Invoked via Pipeline
  def message_created_workflow(%{"type" => "message.created.truncated", "data" => %{"object" => %{"grant_id" => vendor_id, "id" => id}}}) do
    Saga.new(%{vendor_id: vendor_id, message_id: id, trigger: :message_created_truncated})
    |> Saga.run(:integration, &fetch_integration/2, &integration_circuit_breaker/3)
    |> Saga.run(:message, &fetch_message/2, &message_circuit_breaker/3)
    |> Saga.run(:parse_emails, &parse_emails_from_message/2)
    |> Saga.with_return(:parse_emails, [])
  end

  def message_created_workflow(%{"type" => "message.created", "data" => %{"object" => %{"grant_id" => vendor_id} = message}}) do
    Saga.new(%{vendor_id: vendor_id, message: message, trigger: :message_created})
    |> Saga.run(:integration, &fetch_integration/2, &integration_circuit_breaker/3)
    |> Saga.run(:parse_emails, &parse_emails_from_message/2)
    |> Saga.with_return(:parse_emails, [])
  end

  @impl Oban.Worker
  # Create a job for each valid integration to peform an incremental sync
  def perform(%Oban.Job{args: %{"task" => "start_incremental_sync"}}) do
    Integrations.list_valid_integrations()
    |> Enum.each(fn integration ->
      %{"task" => "incremental_sync", "vendor_id" => integration.vendor_id}
      |> new()
      |> Oban.insert!()
    end)
  end

  # Perform incremental sync of messages
  # - This is a periodic job to sync new messages since the last sync
  # - Message created webhooks are being used for real time notifications, but this job will catch any messages missed by webhooks
  # - Each page of messages will be passed to the pipeline for processing
  def perform(%Oban.Job{args: %{"task" => "incremental_sync", "vendor_id" => id}}) do
    Saga.new(%{vendor_id: id, trigger: :incremental_sync})
    |> Saga.run(:integration, &fetch_integration/2, &integration_circuit_breaker/3)
    |> Saga.run(:messages, &fetch_messages_since/2, &messages_circuit_breaker/3)
    |> Saga.run(:set_integration_last_synced, &set_integration_last_synced/2, &set_integration_circuit_breaker/3)
    |> maybe_cancel_job()
  end

  # Perform historic sync of messages
  # - This is a one off job that runs when a user connects a new integration
  # - It will sync all messages from the last 30 days
  # - Each page of messages will be passed to the pipeline for processing
  def perform(%Oban.Job{args: %{"task" => "historic_sync", "vendor_id" => id}}) do
    Saga.new(%{vendor_id: id, trigger: :historic_sync})
    |> Saga.run(:integration, &fetch_integration/2, &integration_circuit_breaker/3)
    |> Saga.run(:messages, &fetch_messages_since/2, &messages_circuit_breaker/3)
    |> Saga.run(:set_integration_last_synced, &set_integration_last_synced/2, &set_integration_circuit_breaker/3)
    |> maybe_cancel_job()
  end

  # Transactions
  def fetch_integration(_effects_so_far, %{vendor_id: id}) do
    case Integrations.get_integration_by_vendor_id(id) do
      {:ok, %{valid?: false}} ->
        {:error, :integration_invalid}

      {:ok, integration} ->
        {:ok, integration}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  def fetch_message(%{integration: integration}, %{message_id: id}) do
    ContactProvider.get_message(integration, id)
  end

  def fetch_messages_since(%{integration: integration}, %{trigger: :historic_sync}) do
    ContactProvider.get_all_messages(
      integration,
      &Pipeline.insert/1,
      %{received_after: get_historic_date()}
    )
  end

  def fetch_messages_since(%{integration: integration}, _attrs) do
    ContactProvider.get_all_messages(
      integration,
      &Pipeline.insert/1,
      %{received_after: get_incremental_date(integration.last_synced)}
    )
  end

  # Message.created
  def parse_emails_from_message(%{integration: integration}, %{message: message}) do
    {:ok, get_emails(message, integration.email_address)}
  end

  # Message.created.truncated
  def parse_emails_from_message(%{integration: integration, message: message}, _attrs) do
    {:ok, get_emails(message, integration.email_address)}
  end

  # Compensations
  def integration_circuit_breaker({:error, error}, _effects_so_far, %{vendor_id: id, trigger: trigger}) when error in [:not_found, :integration_invalid] do
    Logger.error("Error processing #{trigger}: unable to fetch integration with vendor_id #{id} due to #{inspect(error)}")
    {:cancel, "integration #{id} #{error}"}
  end

  def integration_circuit_breaker(error, _effects_so_far, %{vendor_id: id, trigger: trigger}) do
    Logger.error("Error processing #{trigger}: unable to fetch integration with vendor_id #{id} due to #{inspect(error)}")
    {:abort_with_error, error}
  end

  def message_circuit_breaker(%{status: status}, %{integration: integration}, %{vendor_id: vendor_id, message_id: id, trigger: trigger}) when status in [:unauthorized, :forbidden] do
    set_integration_invalid(integration)
    Logger.error("Error processing #{trigger}: unable to fetch message with id #{id} for integration with vendor_id #{vendor_id} due to #{status} error")

    {:cancel, "marking integration #{vendor_id} as invalid"}
  end

  def message_circuit_breaker(%{status: :not_found}, _, %{vendor_id: vendor_id, message_id: id, trigger: trigger}) do
    Logger.error("Error processing #{trigger}: unable to fetch message with id #{id} for integration with vendor_id #{vendor_id} due to message not found")
    {:cancel, "skipping message, not found"}
  end

  def message_circuit_breaker(error, _effects_so_far, %{vendor_id: vendor_id, message_id: id, trigger: trigger}) do
    Logger.error("Error processing #{trigger}: unable to fetch message with id #{id} for integration with vendor_id #{vendor_id} due to #{inspect(error)}")
    {:abort_with_error, error}
  end

  def messages_circuit_breaker(%{status: status}, %{integration: %{vendor_id: vendor_id} = integration}, %{trigger: trigger}) when status in [:unauthorized, :forbidden] do
    set_integration_invalid(integration)
    Logger.error("Error processing #{trigger}: unable to fetch messages for integration with vendor_id #{vendor_id} due to #{status} error")

    {:cancel, "marking integration #{vendor_id} as invalid"}
  end

  def messages_circuit_breaker(error, %{integration: %{vendor_id: vendor_id}}, %{trigger: trigger}) do
    Logger.error("Error processing #{trigger}: unable to fetch messages for integration with vendor_id #{vendor_id} due to #{inspect(error)}")
    {:abort_with_error, error}
  end

  # Helpers
  def set_integration_invalid(integration) do
    Integrations.update_integration(integration, %{valid?: false, invalid_since: DateTime.utc_now()})
  end

  def set_integration_last_synced(%{integration: integration}, %{trigger: :incremental_sync}) do
    Integrations.update_integration(integration, %{last_synced: DateTime.utc_now()})
  end

  def set_integration_last_synced(%{integration: integration}, %{trigger: :historic_sync}) do
    Integrations.update_integration(integration, %{last_synced: DateTime.utc_now(), historic_completed?: true})
  end

  def set_integration_circuit_breaker(error, %{integration: %{vendor_id: vendor_id}}, %{trigger: trigger}) do
    Logger.error("Error processing #{trigger}: unable to update integration with vendor_id #{vendor_id} due to #{inspect(error)}")
    {:abort_with_error, error}
  end

  def get_historic_date() do
    DateTime.utc_now()
    |> DateTime.add(-30, :day)
    |> DateTime.to_unix()
  end

  # Offset last synced by 2 hours so there is overlap
    # between the last sync and the current sync (in case of missed messages)
  def get_incremental_date(last_synced) do
    last_synced
    |> DateTime.add(-2, :hour)
    |> DateTime.to_unix()
  end

  def get_emails(message, exclude_email_address) do
    [:from, :to, :cc, :bcc]
    |> Enum.map(&indifferent_get(message, &1, []))
    |> List.flatten()
    |> Enum.map(&indifferent_get(&1, :email))
    |> Enum.reject(&(&1 == exclude_email_address || is_nil(&1)))
    |> Enum.uniq()
  end

  # Webhook payloads will have string keys, but values from the SDK will have atom keys
  def indifferent_get(map, key, default \\ nil) when is_atom(key) do
    v = Map.get(map, key) || Map.get(map, to_string(key))
    case v do
      nil -> default
      _ -> v
    end
  end
end
