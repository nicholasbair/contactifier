defmodule Contactifier.Contacts.Worker do
  require Logger

  use Oban.Worker,
    queue: :contacts,
    max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id, "account_id" => account_id} = _args}) do
    # Don't create a contact in the DB if:
      # 1. A contact with the same vendor_id already exists in the DB
      # 2. A contact with the same email already exists in the DB (a user could manually create a contact with the same email)
      # 3. The user doesn't have a valid integration (since the app needs to fetch the contact from the vendor API)
    with {:error, :not_found} <- Contactifier.Contacts.get_contact_by_vendor_id(id),
      {:ok, integration} <- Contactifier.Integrations.get_integration_by_vendor_id(account_id),
      {:ok, %{source: "inbox", emails: [%{email:  email} | _tail]} = _contact} <- ExNylas.Contacts.find(%ExNylas.Connection{access_token: integration.token}, id),
      {:error, :not_found} <- Contactifier.Contacts.get_contact_by_email(email) do

        with {:ok, _contact} <- Contactifier.Contacts.create_contact(%{vendor_id: id, email: email}) do
          Logger.info("Created contact with email #{email} for vendor_id #{account_id}")
        end
    end
  end
end
