defmodule Contactifier.Integrations.Integration do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "integrations" do
    field :name, :string
    field :scopes, {:array, :string}
    field :state, :string
    field :user_id, :binary_id

    timestamps()
  end

  @doc false
  def changeset(integration, attrs) do
    integration
    |> cast(attrs, [:name, :scopes, :state])
    |> validate_required([:name, :scopes, :state])
  end
end
