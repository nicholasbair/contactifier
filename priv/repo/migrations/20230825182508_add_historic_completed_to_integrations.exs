defmodule Contactifier.Repo.Migrations.AddHistoricCompletedToIntegrations do
  use Ecto.Migration

  def change do
    alter table(:integrations) do
      add :historic_completed?, :boolean, default: false
    end
  end
end
