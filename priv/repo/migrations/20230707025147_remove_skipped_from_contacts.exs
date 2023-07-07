defmodule Contactifier.Repo.Migrations.RemoveSkippedFromContacts do
  use Ecto.Migration

  def change do
    alter table(:contacts) do
      remove :skipped?
    end
  end
end
