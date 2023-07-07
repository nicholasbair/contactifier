defmodule Contactifier.Integrations do
  @moduledoc """
  The Integrations context.
  """

  import Ecto.Query, warn: false
  alias Contactifier.Repo

  alias Contactifier.Integrations.Integration

  @doc """
  Returns the list of integrations.

  ## Examples

      iex> list_integrations()
      [%Integration{}, ...]

  """
  def list_integrations do
    Repo.all(Integration)
  end

  @doc """
  Gets a single integration.

  Raises `Ecto.NoResultsError` if the Integration does not exist.

  ## Examples

      iex> get_integration!(123)
      %Integration{}

      iex> get_integration!(456)
      ** (Ecto.NoResultsError)

  """
  def get_integration!(id), do: Repo.get!(Integration, id)

  @doc """
  Gets a single valid integration.

  ## Examples

      iex> get_integration_by_vendor_id(nil)
      {:error, :not_found}

      iex> get_integration_by_vendor_id("123")
      {:ok, %Integration{}}

      iex> get_integration_by_vendor_id("456")
      {:error, :not_found}

  """
  def get_integration_by_vendor_id(val) when is_nil(val) do
    Repo.normalize_one(val)
  end

  def get_integration_by_vendor_id(vendor_id) do
    Repo.get_by(Integration, vendor_id: vendor_id, valid?: true)
    |> Repo.normalize_one()
  end

  @doc """
  Creates a integration.

  ## Examples

      iex> create_integration(%{field: value})
      {:ok, %Integration{}}

      iex> create_integration(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_integration(attrs \\ %{}) do
    %Integration{}
    |> Integration.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Create or update an integration.

  ## Examples

      iex> upsert_integration(%{field: value})
      {:ok, %Integration{}}

      iex> upsert_integration(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def upsert_integration(attrs \\ %{}) do
    case get_integration_by_vendor_id(attrs["vendor_id"]) do
      {:error, :not_found} -> create_integration(attrs)
      {:ok, integration} -> update_integration(integration, attrs)
    end
  end

  @doc """
  Updates a integration.

  ## Examples

      iex> update_integration(integration, %{field: new_value})
      {:ok, %Integration{}}

      iex> update_integration(integration, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_integration(%Integration{} = integration, attrs) do
    integration
    |> Integration.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a integration.

  ## Examples

      iex> delete_integration(integration)
      {:ok, %Integration{}}

      iex> delete_integration(integration)
      {:error, %Ecto.Changeset{}}

  """
  def delete_integration(%Integration{} = integration) do
    Repo.delete(integration)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking integration changes.

  ## Examples

      iex> change_integration(integration)
      %Ecto.Changeset{data: %Integration{}}

  """
  def change_integration(%Integration{} = integration, attrs \\ %{}) do
    Integration.changeset(integration, attrs)
  end
end
