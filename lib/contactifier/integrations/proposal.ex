defmodule Contactifier.Integrations.Proposal do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "proposals" do
    field :user_id, :binary_id

    timestamps()
  end

  @doc false
  def changeset(integration, attrs) do
    integration
    |> cast(attrs, [:user_id])
    |> validate_required([:user_id])
  end
end
