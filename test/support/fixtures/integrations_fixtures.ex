defmodule Contactifier.IntegrationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Contactifier.Integrations` context.
  """

  @doc """
  Generate a integration.
  """
  def integration_fixture(attrs \\ %{}) do
    {:ok, integration} =
      attrs
      |> Enum.into(%{
        name: "some name",
        scopes: ["option1", "option2"],
        state: "some state"
      })
      |> Contactifier.Integrations.create_integration()

    integration
  end
end
