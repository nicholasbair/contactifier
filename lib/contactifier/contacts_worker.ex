defmodule Contactifier.Contacts.Worker do
  require Logger

  use Oban.Worker,
    queue: :contacts,
    max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id, "account_id" => account_id} = _args}) do
    with {:error, :not_found} <- Contactifier.Contacts.get_contact(id),
      {:ok, integration} <- Contactifier.Integrations.get_integration_by_vendor_id(account_id),
      {:ok, %{source: "inbox"} = contact} <- ExNylas.Contacts.find(%ExNylas.Connection{access_token: integration.token}, id) do

        # Parsed contacts only contain an email (e.g. no first_name, etc.)
        email =
          contact.emails
          |> List.first
          |> Map.get(:email)

        Logger.info("Creating contact with email #{email} for vendor_id #{account_id}")

        Contactifier.Contacts.create_contact(%{vendor_id: id, email: email})
    end
  end
end
