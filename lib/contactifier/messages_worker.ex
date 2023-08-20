defmodule Contactifier.Messages.Worker do
  require Logger

  alias Contactifier.{
    Integrations,
    Integrations.ContactProvider
  }

  use Oban.Worker,
    queue: :messages,
    max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => "message.created.truncated", "data" => %{"object" => %{"grant_id" => vendor_id, "id" => id}}}}) do
    with {:ok, integration} <- Integrations.get_integration_by_vendor_id(vendor_id),
      {:ok, message} <- ContactProvider.get_message(integration, id) do
        message
        |> process_message(integration.email_address)
    else {:error, reason} ->
      Logger.error("Error processing message.created.truncated webhook: #{inspect(reason)}")
    end
  end

  def perform(%Oban.Job{args: %{"type" => "message.created", "data" => %{"object" => %{"grant_id" => vendor_id} = message}}}) do
    with {:ok, integration} <- Integrations.get_integration_by_vendor_id(vendor_id) do
      message
      |> process_message(integration.email_address)
    else {:error, reason} ->
      Logger.error("Error processing message.created webhook: #{inspect(reason)}")
    end
  end

  # Create a job for each valid integration to peform an incremental sync
  def perform(%Oban.Job{args: %{"task" => "start_incremental_sync"}}) do
    Integrations.list_valid_integrations()
    |> Enum.each(fn integration ->
      %{"task" => "incremental_sync", "integration_id" => integration.id}
      |> new()
      |> Oban.insert!()
    end)
  end

  # Perform incremental sync of messages
  # - This is a periodic job to sync new messages since the last sync
  # - Message created webhooks are being used for real time notifications, but this job will catch any messages missed by webhooks
  # - Not filtering based on the inbox here, as the webhook processing does not either
  def perform(%Oban.Job{args: %{"task" => "incremental_sync", "integration_id" => integration_id}}) do
    with {:ok, integration} <- Integrations.get_integration(integration_id),
      {:ok, messages} <- ContactProvider.get_messages(integration, %{received_after: DateTime.to_unix(integration.last_synced)}) do

        # Not using process_message/2 here so that email addresses can be deduped across all messages in the results
        process_messages(messages, integration.email_address)

        # Set last synced so that the next incremental sync knows where to start
        {:ok, _} = Integrations.update_integration(integration, %{last_synced: DateTime.utc_now()})

    else {:error, reason} ->
      Logger.error("Error completing historic message sync: #{inspect(reason)}")
    end
  end

  # Perform historic sync of messages
  # - This is a one off job that runs when a user connects a new integration
  # - It will sync all messages from the last 14 days in the inbox folder/label
  # - Then create a contact for each unique email address in the message
  def perform(%Oban.Job{args: %{"task" => "historic_sync", "integration_id" => integration_id}}) do
    with {:ok, integration} <- Integrations.get_integration(integration_id),
      {:ok, %{id: inbox_id} = _inbox_folder} <- ContactProvider.get_inbox_folder(integration),
      {:ok, messages} <- ContactProvider.get_messages(integration, %{in: inbox_id, received_after: get_historic_date()}) do

        # Not using process_message/2 here so that email addresses can be deduped across all historic messages
        process_messages(messages, integration.email_address)

        # Set last synced so that incremental sync knows where to start
        {:ok, _} = Integrations.update_integration(integration, %{last_synced: DateTime.utc_now()})

    else {:error, reason} ->
      Logger.error("Error completing historic message sync: #{inspect(reason)}")
    end
  end

  def get_historic_date() do
    DateTime.utc_now()
    |> DateTime.add(-14, :day)
    |> DateTime.to_unix()
  end

  defp process_messages(messages, email_address) do
    messages
    |> Enum.map(&get_emails(&1, email_address))
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.each(&insert_contact_job(&1))
  end

  def process_message(message, email_address) do
    message
    |> get_emails(email_address)
    |> Enum.uniq()
    |> Enum.each(&insert_contact_job(&1))
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
