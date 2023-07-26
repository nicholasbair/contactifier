defmodule ContactifierWeb.ContactLive.Index do
  use ContactifierWeb, :live_view

  alias Contactifier.Contacts
  alias Contactifier.Contacts.Contact
  alias Contactifier.Customers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :contacts, Contacts.list_parsed_contacts())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    contact = Contacts.get_contact!(id)
    customers =
      Customers.list_customers()
      |> Enum.map(fn customer -> {customer.name, customer.id} end)

    # Setting customers independently of contact in assign/3 doesn't work
    # Bit of a hack, passing customers on contact map
    contact = Map.put(contact, :customers, customers)

    socket
    |> assign(:page_title, "Assign Contact")
    |> assign(:contact, contact)
  end

  defp apply_action(socket, :new, _params) do
    contact = %Contact{}
    customers =
      Customers.list_customers()
      |> Enum.map(fn customer -> {customer.name, customer.id} end)

    # Setting customers independently of contact in assign/3 doesn't work
    # Bit of a hack, passing customers on contact map
    contact = Map.put(contact, :customers, customers)

    socket
    |> assign(:page_title, "New Contact")
    |> assign(:contact, contact)
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Unassigned Contacts")
    |> assign(:contact, nil)
  end

  @impl true
  def handle_info({ContactifierWeb.ContactLive.FormComponent, {:saved, contact}}, socket) do
    {:noreply, stream_insert(socket, :contacts, contact)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    contact = Contacts.get_contact!(id)
    {:ok, _} = Contacts.soft_delete_contact(contact)

    {:noreply, stream_delete(socket, :contacts, contact)}
  end
end
