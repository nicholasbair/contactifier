defmodule Contactifier.Messages.Worker do
  require Logger

  import Contactifier.Worker.Util, only: [maybe_cancel_job: 1]

  alias Contactifier.{
    Integrations,
    Integrations.ContactProvider,
    Saga
  }

  use Oban.Worker,
    queue: :messages,
    max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => "message.created.truncated", "data" => %{"object" => %{"grant_id" => vendor_id, "id" => id}}}}) do
    Saga.new(%{vendor_id: vendor_id, message_id: id, trigger: :message_created_truncated})
    |> Saga.run(:integration, &fetch_integration/2, &integration_circuit_breaker/3)
    |> Saga.run(:message, &fetch_message/2, &message_circuit_breaker/3)
    |> Saga.run(:handle_message, &handle_message/2)
    |> maybe_cancel_job()
  end

  def perform(%Oban.Job{args: %{"type" => "message.created", "data" => %{"object" => %{"grant_id" => vendor_id} = message}}}) do
    Saga.new(%{vendor_id: vendor_id, message: message, trigger: :message_created})
    |> Saga.run(:integration, &fetch_integration/2, &integration_circuit_breaker/3)
    |> Saga.run(:handle_message, &handle_message/2)
  end

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
  # - Not filtering based on the inbox here, as the webhook processing does not either
  def perform(%Oban.Job{args: %{"task" => "incremental_sync", "vendor_id" => id}}) do
    Saga.new(%{vendor_id: id, trigger: :incremental_sync})
    |> Saga.run(:integration, &fetch_integration/2, &integration_circuit_breaker/3)
    |> Saga.run(:messages, &fetch_messages_since/2, &messages_circuit_breaker/3)
    |> Saga.run(:handle_messages, &handle_messages/2)
    |> Saga.run(:set_integration_last_synced, &set_integration_last_synced/2, &set_integration_circuit_breaker/3)
    |> maybe_cancel_job()
  end

  # Perform historic sync of messages
  # - This is a one off job that runs when a user connects a new integration
  # - It will sync all messages from the last 7 days in the inbox folder/label
  # - Then create a contact for each unique email address in the message
  def perform(%Oban.Job{args: %{"task" => "historic_sync", "vendor_id" => id}}) do
    Saga.new(%{vendor_id: id, trigger: :historic_sync})
    |> Saga.run(:integration, &fetch_integration/2, &integration_circuit_breaker/3)
    |> Saga.run(:messages, &fetch_messages_since/2, &messages_circuit_breaker/3)
    |> Saga.run(:handle_messages, &handle_messages/2)
    |> Saga.run(:set_integration_last_synced, &set_integration_last_synced/2, &set_integration_circuit_breaker/3)
    |> maybe_cancel_job()
  end

  # Transactions
  def fetch_integration(_effects_so_far, %{vendor_id: id}) do
    Integrations.get_integration_by_vendor_id(id)
  end

  def fetch_message(%{integration: integration}, %{message_id: id}) do
    ContactProvider.get_message(integration, id)
  end

  def fetch_messages_since(%{integration: integration}, %{trigger: :historic_sync}) do
    ContactProvider.get_messages(integration, %{received_after: get_historic_date()})
  end

  def fetch_messages_since(%{integration: integration}, _attrs) do
    ContactProvider.get_messages(integration, %{received_after: DateTime.to_unix(integration.last_synced)})
  end

  def handle_message(%{integration: integration, message: message}, _attrs) do
    message
    |> get_emails(integration.email_address)
    |> Enum.uniq()
    |> Enum.each(&insert_contact_job(&1))
  end

  def handle_message(%{integration: integration}, %{message: message}) do
    message
    |> get_emails(integration.email_address)
    |> Enum.uniq()
    |> Enum.each(&insert_contact_job(&1))
  end

  def handle_messages(%{integration: integration, messages: messages}, _attrs) do
    messages
    |> Enum.map(&get_emails(&1, integration.email_address))
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.each(&insert_contact_job(&1))
  end

  # Compensations
  def integration_circuit_breaker({:error, :not_found}, _effects_so_far, %{vendor_id: id, trigger: trigger}) do
    Logger.error("Error processing #{trigger}: unable to fetch integration with vendor_id #{id} due to integration not found")
    {:cancel, "integration #{id} not found"}
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
    |> DateTime.add(-7, :day)
    |> DateTime.to_unix()
  end

  def get_emails(message, email_address) do
    [:from, :to, :cc, :bcc]
    |> Enum.map(&indifferent_get(message, &1, []))
    |> List.flatten()
    |> Enum.map(&indifferent_get(&1, :email))
    |> Enum.reject(&(&1 == email_address || is_nil(&1)))
  end

  def insert_contact_job(email) do
    %{"email" => email}
    |> Contactifier.Contacts.Worker.new()
    |> Oban.insert!()
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
