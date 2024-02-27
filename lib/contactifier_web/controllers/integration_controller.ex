defmodule ContactifierWeb.IntegrationController do
  use ContactifierWeb, :controller

  require Logger

  alias Contactifier.{
    Integrations,
    Integrations.ContactProvider,
    Integrations.Proposals,
    Messages.Worker,
    Saga
  }

  def callback(conn, %{"code" => code, "state" => state} = _params) do
    case auth_saga(code, state, conn.assigns.current_user.id) do
      :ok ->
        conn
        |> put_flash(:info, "Authentication successful!")
        |> redirect(to: ~p"/integrations")
      {_, message} ->
        conn
        |> put_flash(:error, "Authentication unsuccessful: #{message}")
        |> redirect(to: ~p"/integrations")
    end
  end

  def callback(conn, %{"error" => error, "error_code" => error_code, "error_description" => error_description, "state" => state} = _params) do
    Logger.error("Error authenticating with Nylas: #{inspect(error)} #{inspect(error_code)} #{inspect(error_description)}, user_id: #{conn.assigns.current_user.id}")

    with {:ok, proposal} <- Proposals.get_proposal(state), {:ok, _} <- Proposals.delete_proposal(proposal) do
      Logger.info("Deleted proposal with id #{proposal.id} due to error authenticating with Nylas")
    else
      {:error, message} ->
        Logger.error("Error deleting proposal with id #{state} due to #{inspect(message)}")
    end

    conn
    |> put_flash(:error, "Authentication unsuccessful.")
    |> redirect(to: ~p"/integrations")
  end

  def auth_saga(code, state, user_id) do
    Saga.new(%{code: code, state: state, user_id: user_id})
    |> Saga.run(:fetch_proposal, &get_proposal/2, &get_proposal_circuit_breaker/3)
    |> Saga.run(:expired?, &proposal_expired?/2, &proposal_expired_circuit_breaker/3)
    |> Saga.run(:user_match?, &user_match?/2, &user_match_circuit_breaker/3)
    |> Saga.run(:exchange_code, &exchange_code/2, &exchange_code_circuit_breaker/3)
    |> Saga.run(:fetch_grant, &fetch_grant/2, &fetch_grant_circuit_breaker/3)
    |> Saga.run(:upsert_integration, &upsert_integration/2, &upsert_integration_circuit_breaker/3)
    |> Saga.run(:delete_proposal, &delete_proposal/2, &delete_proposal_circuit_breaker/3)
    |> Saga.run(:historic_sync, &historic_sync/2, &historic_sync_circuit_breaker/3)
    |> Saga.finally()
  end

  def get_proposal(_effects_so_far, %{state: state} = _attrs), do: Proposals.get_proposal(state)

  def get_proposal_circuit_breaker(error, _effects_so_far, %{state: state} = _attrs) do
    Logger.error("Error fetching proposal with id #{state} due to #{inspect(error)}")
    {:abort_with_error, "Auth request not found"}
  end

  def proposal_expired?(%{fetch_proposal: proposal} = _effects_so_far, _attrs) do
    case Proposals.expired?(proposal) do
      true -> {:error, "Proposal expired"}
      false -> :ok
    end
  end

  def proposal_expired_circuit_breaker(_error, %{fetch_proposal: proposal} = _effects_so_far, _attrs) do
    Logger.error("Proposal #{proposal.id} expired")
    {:abort_with_error, "Auth request expired"}
  end

  def user_match?(%{fetch_proposal: proposal} = _effects_so_far, attrs) do
    case proposal.user_id === attrs.user_id do
      true -> :ok
      false -> {:error, "User mismatch"}
    end
  end

  def user_match_circuit_breaker(_error, %{fetch_proposal: proposal} = _effects_so_far, attrs) do
    Logger.error("User mismatch for proposal #{proposal.id}, expected #{attrs.user_id} but got #{proposal.user_id}")
    {:abort_with_error, "Auth request for your user not found"}
  end

  def exchange_code(_effects_so_far, %{code: code} = _attrs), do: ContactProvider.exchange_code(code)

  def exchange_code_circuit_breaker(error, %{fetch_proposal: proposal} = _effects_so_far, _attrs) do
    Logger.error("Error exchanging code for token, proposal #{proposal.id}: #{inspect(error)}")
    {:abort_with_error, "Error exchanging authentication code for token"}
  end

  def fetch_grant(%{exchange_code: res} = _effects_so_far, _attrs), do: ContactProvider.get_grant(res.grant_id)

  def fetch_grant_circuit_breaker(error, %{exchange_code: res, fetch_proposal: proposal} = _effects_so_far, _attrs) do
    Logger.error("Error fetching grant with id #{res.grant_id} for proposal #{proposal.id}: #{inspect(error)}")
    {:abort_with_error, "Error completing authentication process, please try again"}
  end

  def upsert_integration(%{fetch_grant: %{data: grant}} = _effects_so_far, %{user_id: user_id} = _attrs) do
    Integrations.upsert_integration(
      %{
        name: "Email Integration",
        description: "This integration has read access to your email.",
        valid?: true,
        user_id: user_id,
        vendor_id: grant.id,
        email_address: grant.email,
        invalid_since: nil,
        provider: grant.provider
      }
    )
  end

  def upsert_integration_circuit_breaker(error, %{fetch_grant: %{data: grant}, fetch_proposal: proposal} = _effects_so_far, _attrs) do
    Logger.error("Error upserting integration with vendor_id #{grant.id} for proposal #{proposal.id}: #{inspect(error)}")
    {:abort_with_error, "Error completing the authentication process, please try again"}
  end

  def delete_proposal(%{fetch_proposal: proposal} = _effects_so_far, _attrs), do: Proposals.delete_proposal(proposal)

  def delete_proposal_circuit_breaker(error, %{fetch_proposal: proposal} = _effects_so_far, _attrs) do
    Logger.error("Error deleting proposal with id #{proposal.id}: #{inspect(error)}")
    :ok
  end

  def historic_sync(%{upsert_integration: %{historic_completed?: true}} = _effects_so_far, _attrs), do: :ok
  def historic_sync(%{upsert_integration: integration} = _effects_so_far, _attrs) do
    %{"task" => "historic_sync", "vendor_id" => integration.vendor_id}
    |> Worker.new()
    |> Oban.insert()
  end

  def historic_sync_circuit_breaker(error, %{upsert_integration: integration} = _effects_so_far, _attrs) do
    Logger.error("Error syncing historic messages for integration with vendor_id #{integration.vendor_id}: #{inspect(error)}")
    :ok
  end
end
