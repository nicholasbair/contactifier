defmodule Contactifier.Repo.Migrations.RemoveNotNullFromContactVendorId do
  use Ecto.Migration

  def change do
    alter table(:contacts) do
      modify :vendor_id, :string, null: true
    end
  end
end
