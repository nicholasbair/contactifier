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

    timestamps()
  end

  @doc false
  def changeset(integration, attrs) do
    integration
    |> cast(attrs, [:name, :scopes, :valid?, :user_id, :token, :vendor_id])
    |> validate_required([:name, :scopes, :valid?, :user_id, :token, :vendor_id])
  end
end
