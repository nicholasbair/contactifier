defmodule Contactifier.Contacts.Worker do

  alias Contactifier.{
    Contacts,
  }

  use Oban.Worker,
    queue: :contacts,
    max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"task" => "check_soft_deleted_contacts"}}) do
    Contacts.get_soft_deleted_for_deletion()
    |> Enum.each(&Contacts.delete_contact&1)
  end
end
