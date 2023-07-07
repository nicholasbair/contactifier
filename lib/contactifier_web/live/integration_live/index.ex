defmodule ContactifierWeb.IntegrationLive.Index do
  use ContactifierWeb, :live_view

  alias Contactifier.Integrations
  alias Contactifier.Integrations.Integration

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :integrations, Integrations.list_integrations())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Integration")
    |> assign(:integration, Integrations.get_integration!(id))
  end

  defp apply_action(socket, :new, _params) do
    {:ok, url} = Integrations.ContactProvider.auth_url()

    socket
    |> assign(:page_title, "New Integration")
    |> assign(:integration, %Integration{})
    |> assign(:auth_url, url)
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
    integration = Integrations.get_integration!(id)
    {:ok, _} = Integrations.delete_integration(integration)

    {:noreply, stream_delete(socket, :integrations, integration)}
  end
end
