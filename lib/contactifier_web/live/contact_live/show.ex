defmodule ContactifierWeb.ContactLive.Show do
  use ContactifierWeb, :live_view

  alias Contactifier.Contacts
  alias Contactifier.Customers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, %{"id" => id})}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    contact = Contacts.get_contact!(id)
    customers =
      Customers.list_customers()
      |> Enum.map(fn customer -> {customer.name, customer.id} end)

    # Settings customers independently of contact in assign/3 doesn't work
    # Bit of a hack, passing customers on contact map
    contact = Map.put(contact, :customers, customers)

    socket
    |> assign(:page_title, "Assign Contact")
    |> assign(:contact, contact)
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    socket
    |> assign(:page_title, "Show Contact")
    |> assign(:contact, Contacts.get_contact!(id))
  end
end
