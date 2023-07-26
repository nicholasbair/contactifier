defmodule ContactifierWeb.IntegrationController do
  use ContactifierWeb, :controller

  # Note - ideally should be using and checking the state param on the callback
  def callback(conn, %{"success" => "true", "provider" => provider, "grant_id" => vendor_id, "email" => email} = _params) do
    with {:ok, _integration} <-
      Contactifier.Integrations.upsert_integration(
        %{
          "name" => "Email Integration",
          "description" => "This integration has read access to your email.",
          "valid?" => true,
          "user_id" => conn.assigns.current_user.id,
          "vendor_id" => vendor_id,
          "email_address" => email,
          "invalid_since" => nil,
          "provider" => provider
        }) do

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

  def callback(conn, %{"success" => "false"} = _params) do
    conn
    |> put_flash(:error, "Authentication unsuccessful.")
    |> redirect(to: ~p"/integrations")
  end
end
