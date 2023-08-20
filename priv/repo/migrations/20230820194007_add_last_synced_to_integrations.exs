defmodule Contactifier.Repo.Migrations.AddLastSyncedToIntegrations do
  use Ecto.Migration

  def change do
    alter table(:integrations) do
      add :last_synced, :utc_datetime
    end
  end
end
