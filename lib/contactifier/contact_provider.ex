defmodule Contactifier.Integrations.ContactProvider do
  @moduledoc """
  Wrapper around ExNylas SDK to provide convenience functions for interacting with the Nylas API.
  """

  import Contactifier.Util, only: [normalize_one: 1]

  @doc """
  Returns the auth URL for the Nylas integration.

  ## Examples

      iex> auth_url()
      {:ok, "https://api.us.nylas.com/v3/connect/login?id=1234abcd"}
  """
  def auth_url(provider, email \\ nil) do
    res =
      connection()
      |> ExNylas.Authentication.Hosted.get_auth_url(
        %{
          redirect_uri: Application.get_env(:contactifier, :nylas_redirect_uri),
          login_hint: email,
          provider: provider,
        }
      )

    case res do
      {:ok, %{data: %{url: url}}} -> {:ok, url}
      _ -> res
    end
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

      iex> get_messages(integration)
      {:ok, [%{id: "1234"}]}

      iex> get_messages()
      {:error, reason}
  """
  def get_messages(integration, query \\ %{}) do
    integration
    |> connection_with_token()
    |> ExNylas.Messages.all(query)
  end

  @doc """
  Get inbox folder for a given integration.

  ## Examples

      iex> get_inbox_folder(integration)
      {:ok, %{data: [%{id: "1234"}]}}

      iex> get_inbox_folder(integration)
      {:error, reason}
  """
  def get_inbox_folder(integration) do
    with {:ok, data} <- connection_with_token(integration) |> ExNylas.Folders.all() do
      data
      |> Enum.find(fn folder -> Enum.member?(["INBOX", "Inbox", "inbox"], folder.name) end)
      |> normalize_one()
    else
      {:error, reason} -> {:error, reason}
    end
  end

end
