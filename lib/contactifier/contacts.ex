defmodule Contactifier.Contacts do
  @moduledoc """
  The Contacts context.
  """

  import Ecto.Query, warn: false
  alias Contactifier.Repo

  alias Contactifier.Contacts.Contact

  @doc """
  Returns the list of contacts.

  ## Examples

      iex> list_contacts()
      [%Contact{}, ...]

  """
  def list_contacts do
    Repo.all(Contact)
  end

  def list_parsed_contacts do
    query = from c in Contact, where: is_nil(c.customer_id) and c.deleted? == false
    Repo.all(query)
  end

  @doc """
  Gets a single contact.

  Raises `Ecto.NoResultsError` if the Contact does not exist.

  ## Examples

      iex> get_contact!(123)
      %Contact{}

      iex> get_contact!(456)
      ** (Ecto.NoResultsError)

  """
  def get_contact!(id), do: Repo.get!(Contact, id)

  def get_contact(id) do
    Contact
    |> Repo.get(id)
    |> Repo.normalize_one()
  end

  def get_contact_by_vendor_id(val) when is_nil(val) do
    Repo.normalize_one(val)
  end

  def get_contact_by_vendor_id(vendor_id) do
    Repo.get_by(Contact, vendor_id: vendor_id)
    |> Repo.normalize_one()
  end

  def get_contact_by_email(email) do
    Repo.get_by(Contact, email: email)
    |> Repo.normalize_one()
  end

  def get_soft_deleted_for_deletion() do
    Contact
    |> where([c], c.deleted? == true and c.deleted_at < datetime_add(^DateTime.utc_now(), -1, "month"))
    |> Repo.all()
  end

  @doc """
  Creates a contact.

  ## Examples

      iex> create_contact(%{field: value})
      {:ok, %Contact{}}

      iex> create_contact(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_contact(attrs \\ %{}) do
    %Contact{}
    |> Contact.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a contact.

  ## Examples

      iex> update_contact(contact, %{field: new_value})
      {:ok, %Contact{}}

      iex> update_contact(contact, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_contact(%Contact{} = contact, attrs) do
    contact
    |> Contact.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Soft deletes a contact.

  ## Examples

      iex> soft_delete_contact(contact)
      {:ok, %Contact{}}

      iex> soft_delete_contact(contact)
      {:error, %Ecto.Changeset{}}

  """
  def soft_delete_contact(%Contact{} = contact) do
    contact
    |> update_contact(%{deleted?: true, deleted_at: DateTime.utc_now()})
  end

  @doc """
  Deletes a contact.

  ## Examples

      iex> delete_contact(contact)
      {:ok, %Contact{}}

      iex> delete_contact(contact)
      {:error, %Ecto.Changeset{}}

  """
  def delete_contact(%Contact{} = contact) do
    Repo.delete(contact)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking contact changes.

  ## Examples

      iex> change_contact(contact)
      %Ecto.Changeset{data: %Contact{}}

  """
  def change_contact(%Contact{} = contact, attrs \\ %{}) do
    Contact.changeset(contact, attrs)
  end
end
