defmodule Contactifier.Repo.Migrations.CreateProposals do
  use Ecto.Migration

  def change do
    create table(:proposals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :binary_id
      timestamps()
    end
  end
end
