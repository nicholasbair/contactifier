defmodule Contactifier.Contacts.Worker do
  require Logger

  use Oban.Worker,
    queue: :contacts,
    max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"email" => email}}) do
    # Don't create a contact in the DB if:
      # 1. A contact with the same email already exists in the DB (a user could manually create a contact with the same email)
    with {:error, :not_found} <- Contactifier.Contacts.get_contact_by_email(email),
      {:ok, _contact} <- Contactifier.Contacts.create_contact(%{email: email}) do
        Logger.info("Created contact with email #{email}")
    end
  end

  def perform(%Oban.Job{args: %{"task" => "check_soft_deleted_contacts"}}) do
    Contactifier.Contacts.get_soft_deleted_for_deletion()
    |> Enum.each(&Contactifier.Contacts.delete_contact&1)
  end
end
