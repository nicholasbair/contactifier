defmodule Contactifier.Repo.Migrations.CreateCustomers do
  use Ecto.Migration

  def change do
    create table(:customers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :arr, :float
      add :domain, :string
      add :name, :string
      add :use_case, :string

      timestamps()
    end
  end
end
