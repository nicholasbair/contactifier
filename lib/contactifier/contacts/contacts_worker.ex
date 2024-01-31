defmodule Contactifier.Contacts.Worker do
  require Logger

  import Contactifier.Worker.Util, only: [maybe_cancel_job: 1]

  alias Contactifier.{
    Contacts,
    Saga
  }

  use Oban.Worker,
    queue: :contacts,
    max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"email" => email}}) do
    # Don't create a contact in the DB if:
      # - A contact with the same email already exists in the DB (a user could manually create a contact with the same email)
    Saga.new(%{email: email})
    |> Saga.run(:should_insert, &should_insert/2, &should_insert_circuit_breaker/3)
    |> Saga.run(:create_contact, &create_contact/2, &create_contact_circuit_breaker/3)
    |> maybe_cancel_job()
  end

  def perform(%Oban.Job{args: %{"task" => "check_soft_deleted_contacts"}}) do
    Contacts.get_soft_deleted_for_deletion()
    |> Enum.each(&Contacts.delete_contact&1)
  end

  def should_insert(_, %{email: email}) do
    case Contacts.get_contact_by_email(email) do
      {:ok, _contact} ->
        {:error, :already_exists}
      {:error, :not_found} ->
        :ok
    end
  end

  def should_insert_circuit_breaker(:already_exists, _, _), do: :cancel

  def create_contact(_, %{email: email}) do
    Contacts.create_contact(%{email: email})
  end

  def create_contact_circuit_breaker(error, _, _) do
    Logger.error("Error creating contact: #{inspect(error)}")
    :abort_with_error
  end
end
