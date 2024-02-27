defmodule Contactifier.Integrations.Proposals.Worker do
  require Logger

  alias Contactifier.Integrations.Proposals

  use Oban.Worker,
    queue: :proposals,
    max_attempts: 3

  @impl Oban.Worker
  def perform(%{args: %{"task" => "check_expired_proposals"}}) do
    Logger.info("Checking for expired proposals")

    Proposals.list_expired_proposals()
    |> Enum.each(&Proposals.delete_proposal/1)

    :ok
  end

  def delete_proposal(proposal) do
    with {:ok, _} <- Proposals.delete_proposal(proposal) do
      Logger.info("Deleted proposal with id #{proposal.id} due to expiration")
    else
      {:error, message} ->
        Logger.error("Error deleting proposal with id #{proposal.id} due to #{inspect(message)}")
    end
  end
end
