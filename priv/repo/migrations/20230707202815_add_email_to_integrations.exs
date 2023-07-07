defmodule Contactifier.Repo.Migrations.AddEmailToIntegrations do
  use Ecto.Migration

  def change do
    alter table(:integrations) do
      add :email_address, :string
    end
  end
end
