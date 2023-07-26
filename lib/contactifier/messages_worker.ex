defmodule Contactifier.Messages.Worker do
  use Oban.Worker,
    queue: :messages,
    max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => "message.created.truncated", "data" => %{"object" => %{"grant_id" => vendor_id, "id" => id}}}}) do
    with {:ok, integration} <- Contactifier.Integrations.get_integration_by_vendor_id(vendor_id),
      {:ok, message} <- ExNylas.Messages.find(%ExNylas.Connection{grant_id: integration.vendor_id}, id) do
        message
        |> process_message(integration.email_address)
    end
  end

  def perform(%Oban.Job{args: %{"type" => "message.created", "data" => %{"object" => %{"grant_id" => vendor_id} = message}}}) do
    with {:ok, integration} <- Contactifier.Integrations.get_integration_by_vendor_id(vendor_id) do
      message
      |> process_message(integration.email_address)
    end
  end

  defp process_message(message, email_address) do
    message
    |> get_emails(email_address)
    |> Enum.each(&insert_contact_job(&1))
  end

  defp get_emails(message, email_address) do
    ["from", "to", "cc", "bcc"]
    |> Enum.map(fn key -> Map.get(message, key, []) end)
    |> List.flatten()
    |> Enum.dedup()
    |> Enum.reject(fn email -> email == email_address end)
  end

  defp insert_contact_job(email) do
    %{"email" => email}
    |> Contactifier.Contacts.Worker.new()
    |> Oban.insert!()
  end
end
