defmodule Contactifier.CustomersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Contactifier.Customers` context.
  """

  @doc """
  Generate a customer.
  """
  def customer_fixture(attrs \\ %{}) do
    {:ok, customer} =
      attrs
      |> Enum.into(%{
        arr: 120.5,
        domain: "some domain",
        name: "some name",
        use_case: "some use_case"
      })
      |> Contactifier.Customers.create_customer()

    customer
  end
end
