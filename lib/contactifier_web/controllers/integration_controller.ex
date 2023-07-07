defmodule ContactifierWeb.IntegrationController do
  use ContactifierWeb, :controller
  alias Contactifier.Integrations.ContactProvider

  # Note - ideally should be using and checking the state param on the callback
  def callback(conn, params) do
    with {:ok, account} <- ContactProvider.exchange_code_for_token(params["code"]),
          {:ok, integration} <- Contactifier.Integrations.upsert_integration(%{"name" => "Email/Contacts", "scopes" => ["email.read_only", "contacts.read_only"], "valid?" => true, "user_id" => conn.assigns.current_user.id, "token" => account.access_token, "vendor_id" => account.account_id}) do

      # If there is only one valid token, SDK will return an error from the Nylas API
      # Calling revoke here will ensure there is only ever one valid token
      ContactProvider.revoke_all_except(integration)

      conn
      |> put_flash(:info, "Authentication successful!")
      |> redirect(to: ~p"/integrations")
    else
      {:error, _} ->
        conn
        |> put_flash(:error, "Authentication unsuccessful.")
        |> redirect(to: ~p"/integrations")
    end
  end
end
