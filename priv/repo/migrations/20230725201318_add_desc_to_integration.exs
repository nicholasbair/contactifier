defmodule Contactifier.Repo.Migrations.AddDescToIntegration do
  use Ecto.Migration

  def change do
    alter table(:integrations) do
      add :description, :string
    end
  end
end
