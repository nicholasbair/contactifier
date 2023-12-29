defmodule Contactifier.Repo.Migrations.AddSoftDeleteToContacts do
  use Ecto.Migration

  def change do
    alter table(:contacts) do
      add :deleted?, :boolean, default: false
      add :deleted_at, :utc_datetime
    end
  end
end
