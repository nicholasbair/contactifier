defmodule Contactifier.Integrations.Integration do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "integrations" do
    field :name, :string
    field :scopes, {:array, :string}
    field :valid?, :boolean
    field :user_id, :binary_id
    field :token, Contactifier.Encrypted.Binary
    field :vendor_id, :string
    field :email_address, :string
    field :invalid_since, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(integration, attrs) do
    integration
    |> cast(attrs, [:name, :scopes, :valid?, :user_id, :token, :vendor_id, :email_address, :invalid_since])
    |> validate_required([:name, :scopes, :valid?, :user_id, :token, :vendor_id, :email_address])
  end
end
