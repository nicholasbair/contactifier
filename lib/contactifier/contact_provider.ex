defmodule Contactifier.Integrations.ContactProvider do
  @moduledoc """
  Wrapper around ExNylas to provide convenience functions for interacting with the Nylas API.
  """

  @doc """
  Returns the auth URL for the Nylas integration.

  ## Examples

      iex> auth_url()
      {:ok, "https://api.nylas.com/oauth/authorize?client_id=1234&redirect_uri=https://example.com&response_type=code&scopes=email.read_only,contacts.read_only"}
  """
  def auth_url() do
    __MODULE__.connection()
    |> ExNylas.Authentication.Hosted.get_auth_url(
      %{
        redirect_uri: Application.get_env(:contactifier, :nylas_redirect_uri),
        scopes: ["email.read_only", "contacts.read_only"],
        response_type: "code"
      }
    )
  end

  def auth_url(email) do
    __MODULE__.connection()
    |> ExNylas.Authentication.Hosted.get_auth_url(
      %{
        redirect_uri: Application.get_env(:contactifier, :nylas_redirect_uri),
        scopes: ["email.read_only", "contacts.read_only"],
        response_type: "code",
        login_hint: email
      }
    )
  end

  @doc """
  Returns the connection for the Nylas integration.

  ## Examples

      iex> connection()
      %ExNylas.Connection{
        api_server: "https://api.nylas.com",
        client_id: "1234",
        client_secret: "5678"
      }
  """
  def connection() do
    %ExNylas.Connection{
      api_server: Application.get_env(:contactifier, :nylas_api_server),
      client_id: Application.get_env(:contactifier, :nylas_client_id),
      client_secret: Application.get_env(:contactifier, :nylas_client_secret),
    }
  end

  @doc """
  Returns the connection for the Nylas integration with the given token.

  ## Examples

    iex> connection_with_token("abcd")
    %ExNylas.Connection{
        api_server: "https://api.nylas.com",
        client_id: "1234",
        client_secret: "5678",
        access_token: "abcd"
      }
  """
  def connection_with_token(%{token: token} = _integration) do
    %ExNylas.Connection{
      api_server: Application.get_env(:contactifier, :nylas_api_server),
      access_token: token
    }
  end

  @doc """
  Returns the Nylas connected account.

  ## Examples

      iex> exchange_code_for_token("abcd")
      {:ok, %ExNylas.Account{
        account_id: "abcd",
        access_token: "efgh",
        email_address: "nick@example.com"
      }}
  """
  def exchange_code_for_token(code) do
    connection()
    |> ExNylas.Authentication.Hosted.exchange_code_for_token(code)
  end

  @doc """
  Revokes all tokens except the given token.

  ## Examples

      iex> revoke_all_except(integration)
      {:ok, %{success: true}}

      iex> revoke_all_except(integration)
      {:error, reason}
  """
  def revoke_all_except(%{token: token, vendor_id: id} = _integration) do
    connection()
    |> ExNylas.Authentication.revoke_all(id, token)
  end

  @doc """
  Revokes all tokens.

  ## Examples

      iex> revoke_all(integration)
      {:ok, %{success: true}}

      iex> revoke_all(integration)
      {:error, reason}
  """
  def revoke_all(%{vendor_id: id} = _integration) do
    connection()
    |> ExNylas.Authentication.revoke_all(id)
  end

  @doc """
  Revoke and downgrade a given integration.

  ## Examples

      iex> delete_integration(integration)
      {:ok, %{success: true}}

      iex> delete_integration(integration)
      {:error, reason}
  """
  def delete_integration(%{vendor_id: id} = integration) do
    integration
    |> revoke_all()

    connection()
    |> ExNylas.ManagementAccounts.delete(id)
  end
end
