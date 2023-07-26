defmodule Contactifier.Repo.Migrations.AddProviderToIntegrations do
  use Ecto.Migration

  def change do
    alter table(:integrations) do
      add :provider, :string
    end
  end
end
