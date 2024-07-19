defmodule Contactifier.Integrations.ContactProvider do
  @moduledoc """
  Wrapper around ExNylas SDK to provide convenience functions for interacting with the Nylas API.
  """

  @doc """
  Returns the auth URL for the Nylas integration.

  ## Examples

      iex> auth_url()
      {:ok, "https://api.us.nylas.com/v3/connect/login?id=1234abcd"}
  """
  def auth_url(provider, proposal_id, email \\ nil) do
    connection_with_client_creds()
    |> ExNylas.HostedAuthentication.get_auth_url(
      %{
        redirect_uri: Application.get_env(:contactifier, :nylas_redirect_uri),
        login_hint: email,
        provider: provider,
        response_type: "code",
        state: proposal_id,
      }
    )
  end

  @doc """
  Exchange the code for a grant.

  ## Examples

      iex> exchange_code("1234abcd")
      {:ok, %{grant_id: "abcd"}}

      iex> exchange_code("1234abcd")
      {:error, reason}
  """
  def exchange_code(code) do
    connection_with_client_creds()
    |> ExNylas.HostedAuthentication.exchange_code_for_token(
      code,
      Application.get_env(:contactifier, :nylas_redirect_uri)
    )
  end

  @doc """
  Return the Nylas grant.

  ## Examples

      iex> get_grant("abcd")
      {:ok, %{grant_id: "abcd"}}

      iex> get_grant("abcd")
      {:error, reason}
  """
  def get_grant(grant_id) do
    connection_with_token(%{vendor_id: grant_id})
    |> ExNylas.Grants.find(grant_id)
  end

  @doc """
  Returns the connection for the Nylas integration.

  ## Examples

      iex> connection()
      %ExNylas.Connection{
        api_server: "https://api.nylas.com",
        api_key: "5678"
      }
  """
  def connection() do
    %ExNylas.Connection{
      api_server: Application.get_env(:contactifier, :nylas_api_server),
      api_key: Application.get_env(:contactifier, :nylas_api_key),
    }
  end

  @doc """
  Returns the connection for the Nylas integration with client credentials.

  ## Examples

      iex> connection()
      %ExNylas.Connection{
        client_id: "1234",
        client_secret: "5678"
      }
  """
  def connection_with_client_creds() do
    %ExNylas.Connection{
      api_server: Application.get_env(:contactifier, :nylas_api_server),
      client_id: Application.get_env(:contactifier, :nylas_client_id),
      api_key: Application.get_env(:contactifier, :nylas_api_key),
      telemetry: true,
    }
  end

  @doc """
  Returns the connection for the Nylas integration with the given token.

  ## Examples

    iex> connection_with_token("abcd")
    %ExNylas.Connection{
        api_server: "https://api.nylas.com",
        grant_id: "abcd",
        api_key: "5678"
      }
  """
  def connection_with_token(%{vendor_id: id} = _integration) do
    %ExNylas.Connection{
      api_server: Application.get_env(:contactifier, :nylas_api_server),
      grant_id: id,
      api_key: Application.get_env(:contactifier, :nylas_api_key),
      telemetry: true,
    }
  end

  @doc """
  Delete a given integration.

  ## Examples

      iex> delete_integration(integration)
      {:ok, %{success: true}}

      iex> delete_integration(integration)
      {:error, reason}
  """
  def delete_integration(%{vendor_id: id} = _integration) do
    connection()
    |> ExNylas.Grants.delete(id)
  end

  @doc """
  Fetch a message.

  ## Examples

      iex> get_message(integration, "1234")
      {:ok, %{id: "1234"}}

      iex> get_message(integration, "1234")
      {:error, reason}
  """
  def get_message(integration, id) do
    integration
    |> connection_with_token()
    |> ExNylas.Messages.find(id)
  end

  @doc """
  Get all messages.

  ## Examples

      iex> get_all_messages(integration, &IO.inspect/1, %{limit: 10})
      {:ok, []}

      iex> get_all_messages(integration, &IO.inspect/1, %{limit: 10})
      {:error, reason}
  """
  def get_all_messages(integration, send_to, query \\ %{}) do
    integration
    |> connection_with_token()
    |> ExNylas.Messages.all(
      delay: 1000,
      send_to: send_to,
      with_metadata: integration,
      query: query
    )
  end
end
