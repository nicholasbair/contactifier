defmodule ContactifierWeb.IntegrationController do
  use ContactifierWeb, :controller

  require Logger

  alias Contactifier.{
    Integrations,
    Integrations.ContactProvider,
    Messages.Worker
  }

  # Note - ideally should be using and checking the state param on the callback
  def callback(conn, %{"code" => code} = _params) do
    with {:ok, %{grant_id: vendor_id}} <- ContactProvider.exchange_code(code),
      {:ok, %{data: %{email: email, provider: provider}}} = ContactProvider.get_grant(vendor_id),
      {:ok, integration} <-
        Integrations.upsert_integration(
        %{
          "name" => "Email Integration",
          "description" => "This integration has read access to your email.",
          "valid?" => true,
          "user_id" => conn.assigns.current_user.id,
          "vendor_id" => vendor_id,
          "email_address" => email,
          "invalid_since" => nil,
          "provider" => provider
        })
        do

      # Nylas no longer does historic sync in API v3, so kick off our own historic sync
      if not integration.historic_completed? do
        %{"task" => "historic_sync", "vendor_id" => integration.vendor_id}
        |> Worker.new()
        |> Oban.insert!()
      end

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

  def callback(conn, %{"error" => error, "error_code" => error_code, "error_description" => error_description} = _params) do
    Logger.error("Error authenticating with Nylas: #{inspect(error)} #{inspect(error_code)} #{inspect(error_description)}")

    conn
    |> put_flash(:error, "Authentication unsuccessful.")
    |> redirect(to: ~p"/integrations")
  end
end
