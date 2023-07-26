defmodule Contactifier.Integrations.Integration do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "integrations" do
    field :name, :string
    field :description, :string
    field :valid?, :boolean
    field :user_id, :binary_id
    field :vendor_id, :string
    field :email_address, :string
    field :invalid_since, :utc_datetime
    field :provider, :string

    timestamps()
  end

  @doc false
  def changeset(integration, attrs) do
    integration
    |> cast(attrs, [:name, :description, :valid?, :user_id, :vendor_id, :email_address, :invalid_since, :provider])
    |> validate_required([:name, :description, :valid?, :user_id, :vendor_id, :email_address, :provider])
  end
end
