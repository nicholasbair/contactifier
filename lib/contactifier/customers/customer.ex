defmodule Contactifier.Customers.Customer do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "customers" do
    field :arr, :float
    field :domain, :string
    field :name, :string
    field :use_case, :string

    timestamps()
  end

  @doc false
  def changeset(customer, attrs) do
    customer
    |> cast(attrs, [:arr, :domain, :name, :use_case])
    |> validate_required([:arr, :domain, :name, :use_case])
  end
end
