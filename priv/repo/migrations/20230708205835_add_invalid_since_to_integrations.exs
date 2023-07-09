defmodule Contactifier.Repo.Migrations.AddInvalidSinceToIntegrations do
  use Ecto.Migration

  def change do
    alter table(:integrations) do
      add :invalid_since, :utc_datetime
    end
  end
end
