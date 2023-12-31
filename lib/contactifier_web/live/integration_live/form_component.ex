defmodule ContactifierWeb.IntegrationLive.FormComponent do
  use ContactifierWeb, :live_component

  alias Contactifier.Integrations

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage integration records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="integration-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <.input
          field={@form[:scopes]}
          type="select"
          multiple
          label="Scopes"
          options={[{"Option 1", "option1"}, {"Option 2", "option2"}]}
        />
        <.input field={@form[:state]} type="text" label="State" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Integration</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{integration: integration} = assigns, socket) do
    changeset = Integrations.change_integration(integration)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"integration" => integration_params}, socket) do
    changeset =
      socket.assigns.integration
      |> Integrations.change_integration(integration_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"integration" => integration_params}, socket) do
    save_integration(socket, socket.assigns.action, integration_params)
  end

  defp save_integration(socket, :edit, integration_params) do
    case Integrations.update_integration(socket.assigns.integration, integration_params) do
      {:ok, integration} ->
        notify_parent({:saved, integration})

        {:noreply,
         socket
         |> put_flash(:info, "Integration updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_integration(socket, :new, integration_params) do
    case Integrations.create_integration(integration_params) do
      {:ok, integration} ->
        notify_parent({:saved, integration})

        {:noreply,
         socket
         |> put_flash(:info, "Integration created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
