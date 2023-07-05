defmodule Contactifier.Repo.Migrations.AddTokenToIntegration do
  use Ecto.Migration

  def change do
    alter table(:integrations) do
      add :token, :binary, null: false
      add :vendor_id, :string, null: false
      add :valid?, :boolean
      remove :state
    end
  end
end
