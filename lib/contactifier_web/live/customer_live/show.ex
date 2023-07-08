defmodule ContactifierWeb.CustomerLive.Show do
  use ContactifierWeb, :live_view

  alias Contactifier.Customers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    customer = Customers.get_customer!(id)

    contacts =
      customer.contacts
      |> Enum.map(fn c -> {c.id, c} end)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:customer, customer)
     |> assign(:contacts, contacts)}
  end

  defp page_title(:show), do: "Show Customer"
  defp page_title(:edit), do: "Edit Customer"
end
