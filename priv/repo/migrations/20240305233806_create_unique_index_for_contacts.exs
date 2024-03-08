defmodule Contactifier.Repo.Migrations.CreateUniqueIndexForContacts do
  use Ecto.Migration

  def change do
    create unique_index(:contacts, [:email])
  end
end
