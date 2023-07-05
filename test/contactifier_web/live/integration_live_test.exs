defmodule ContactifierWeb.IntegrationLiveTest do
  use ContactifierWeb.ConnCase

  import Phoenix.LiveViewTest
  import Contactifier.IntegrationsFixtures

  @create_attrs %{name: "some name", scopes: ["option1", "option2"], state: "some state"}
  @update_attrs %{name: "some updated name", scopes: ["option1"], state: "some updated state"}
  @invalid_attrs %{name: nil, scopes: [], state: nil}

  defp create_integration(_) do
    integration = integration_fixture()
    %{integration: integration}
  end

  describe "Index" do
    setup [:create_integration]

    test "lists all integrations", %{conn: conn, integration: integration} do
      {:ok, _index_live, html} = live(conn, ~p"/integrations")

      assert html =~ "Listing Integrations"
      assert html =~ integration.name
    end

    test "saves new integration", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/integrations")

      assert index_live |> element("a", "New Integration") |> render_click() =~
               "New Integration"

      assert_patch(index_live, ~p"/integrations/new")

      assert index_live
             |> form("#integration-form", integration: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#integration-form", integration: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/integrations")

      html = render(index_live)
      assert html =~ "Integration created successfully"
      assert html =~ "some name"
    end

    test "updates integration in listing", %{conn: conn, integration: integration} do
      {:ok, index_live, _html} = live(conn, ~p"/integrations")

      assert index_live |> element("#integrations-#{integration.id} a", "Edit") |> render_click() =~
               "Edit Integration"

      assert_patch(index_live, ~p"/integrations/#{integration}/edit")

      assert index_live
             |> form("#integration-form", integration: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#integration-form", integration: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/integrations")

      html = render(index_live)
      assert html =~ "Integration updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes integration in listing", %{conn: conn, integration: integration} do
      {:ok, index_live, _html} = live(conn, ~p"/integrations")

      assert index_live |> element("#integrations-#{integration.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#integrations-#{integration.id}")
    end
  end

  describe "Show" do
    setup [:create_integration]

    test "displays integration", %{conn: conn, integration: integration} do
      {:ok, _show_live, html} = live(conn, ~p"/integrations/#{integration}")

      assert html =~ "Show Integration"
      assert html =~ integration.name
    end

    test "updates integration within modal", %{conn: conn, integration: integration} do
      {:ok, show_live, _html} = live(conn, ~p"/integrations/#{integration}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Integration"

      assert_patch(show_live, ~p"/integrations/#{integration}/show/edit")

      assert show_live
             |> form("#integration-form", integration: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#integration-form", integration: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/integrations/#{integration}")

      html = render(show_live)
      assert html =~ "Integration updated successfully"
      assert html =~ "some updated name"
    end
  end
end
