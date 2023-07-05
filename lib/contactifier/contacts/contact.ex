defmodule Contactifier.Contacts.Contact do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "contacts" do
    field :email, :string
    field :first_name, :string
    field :last_name, :string
    field :role, :string
    field :customer_id, :binary_id

    timestamps()
  end

  @doc false
  def changeset(contact, attrs) do
    contact
    |> cast(attrs, [:email, :first_name, :last_name, :role])
    |> validate_required([:email, :first_name, :last_name, :role])
  end
end
