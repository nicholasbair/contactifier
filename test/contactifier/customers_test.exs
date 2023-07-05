defmodule Contactifier.CustomersTest do
  use Contactifier.DataCase

  alias Contactifier.Customers

  describe "customers" do
    alias Contactifier.Customers.Customer

    import Contactifier.CustomersFixtures

    @invalid_attrs %{arr: nil, domain: nil, name: nil, use_case: nil}

    test "list_customers/0 returns all customers" do
      customer = customer_fixture()
      assert Customers.list_customers() == [customer]
    end

    test "get_customer!/1 returns the customer with given id" do
      customer = customer_fixture()
      assert Customers.get_customer!(customer.id) == customer
    end

    test "create_customer/1 with valid data creates a customer" do
      valid_attrs = %{arr: 120.5, domain: "some domain", name: "some name", use_case: "some use_case"}

      assert {:ok, %Customer{} = customer} = Customers.create_customer(valid_attrs)
      assert customer.arr == 120.5
      assert customer.domain == "some domain"
      assert customer.name == "some name"
      assert customer.use_case == "some use_case"
    end

    test "create_customer/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Customers.create_customer(@invalid_attrs)
    end

    test "update_customer/2 with valid data updates the customer" do
      customer = customer_fixture()
      update_attrs = %{arr: 456.7, domain: "some updated domain", name: "some updated name", use_case: "some updated use_case"}

      assert {:ok, %Customer{} = customer} = Customers.update_customer(customer, update_attrs)
      assert customer.arr == 456.7
      assert customer.domain == "some updated domain"
      assert customer.name == "some updated name"
      assert customer.use_case == "some updated use_case"
    end

    test "update_customer/2 with invalid data returns error changeset" do
      customer = customer_fixture()
      assert {:error, %Ecto.Changeset{}} = Customers.update_customer(customer, @invalid_attrs)
      assert customer == Customers.get_customer!(customer.id)
    end

    test "delete_customer/1 deletes the customer" do
      customer = customer_fixture()
      assert {:ok, %Customer{}} = Customers.delete_customer(customer)
      assert_raise Ecto.NoResultsError, fn -> Customers.get_customer!(customer.id) end
    end

    test "change_customer/1 returns a customer changeset" do
      customer = customer_fixture()
      assert %Ecto.Changeset{} = Customers.change_customer(customer)
    end
  end
end
