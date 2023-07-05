defmodule Contactifier.Repo.Migrations.AddVendorIdToContacts do
  use Ecto.Migration

  def change do
    alter table(:contacts) do
      add :vendor_id, :string, null: false
      add :skipped?, :boolean, default: false
    end
  end
end
