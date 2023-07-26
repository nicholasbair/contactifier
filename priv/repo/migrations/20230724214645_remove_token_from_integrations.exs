defmodule Contactifier.Repo.Migrations.RemoveTokenFromIntegrations do
  use Ecto.Migration

  def change do
    alter table(:integrations) do
      remove :token
    end
  end
end
