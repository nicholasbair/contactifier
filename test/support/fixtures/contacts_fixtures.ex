defmodule Contactifier.ContactsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Contactifier.Contacts` context.
  """

  @doc """
  Generate a contact.
  """
  def contact_fixture(attrs \\ %{}) do
    {:ok, contact} =
      attrs
      |> Enum.into(%{
        email: "some email",
        first_name: "some first_name",
        last_name: "some last_name",
        role: "some role"
      })
      |> Contactifier.Contacts.create_contact()

    contact
  end
end
