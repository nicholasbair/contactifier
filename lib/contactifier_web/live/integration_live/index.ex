defmodule ContactifierWeb.IntegrationLive.Index do
  use ContactifierWeb, :live_view

  alias Contactifier.Integrations
  alias Contactifier.Integrations.Integration
  alias Contactifier.Integrations.ContactProvider

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :integrations, Integrations.list_integrations_for_user(socket.assigns.current_user.id))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Integration")
    |> assign(:integration, %Integration{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Integrations")
    |> assign(:integration, nil)
  end

  @impl true
  def handle_info({ContactifierWeb.IntegrationLive.FormComponent, {:saved, integration}}, socket) do
    {:noreply, stream_insert(socket, :integrations, integration)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    integration = Integrations.get_integration_for_user!(socket.assigns.current_user.id, id)
    ContactProvider.delete_integration(integration)
    {:ok, _} = Integrations.delete_integration(integration)

    {:noreply, stream_delete(socket, :integrations, integration)}
  end

  @impl true
  def handle_event("start_auth", %{"value" => provider}, socket) when provider in ["google", "microsoft"] do
    {:ok, proposal} = Integrations.Proposals.create_proposal(%{user_id: socket.assigns.current_user.id})
    {:ok, url} = Integrations.ContactProvider.auth_url(provider, proposal.id)
    {:noreply, redirect(socket, external: url)}
  end

  @impl true
  def handle_event("start_reauth", %{"id" => id}, socket) do
    integration = Integrations.get_integration_for_user!(socket.assigns.current_user.id, id)
    {:ok, proposal} = Integrations.Proposals.create_proposal(%{user_id: socket.assigns.current_user.id})
    {:ok, url} = Integrations.ContactProvider.auth_url(integration.provider, proposal.id, integration.email_address)

    {:noreply, redirect(socket, external: url)}
  end
end
