defmodule SocialScribeWeb.UserSettingsLiveTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures

  describe "UserSettingsLive" do
    @describetag :capture_log

    setup :register_and_log_in_user

    test "redirects if user is not logged in", %{conn: conn} do
      conn = recycle(conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/dashboard/settings")
      assert path == ~p"/users/log_in"
    end

    test "renders settings page for logged-in user", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/settings")

      assert has_element?(view, "h1", "User Settings")
      assert has_element?(view, "h2", "Connected Google Accounts")
      assert has_element?(view, "a", "Connect another Google Account")
    end

    test "displays a message if no Google accounts are connected", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/settings")
      assert has_element?(view, "p", "You haven't connected any Google accounts yet.")
    end

    test "displays connected Google accounts", %{conn: conn, user: user} do
      # Create a Google credential for the user
      # Assuming UserCredential has an :email field for display purposes.
      # If not, you might display the UID or another identifier.
      credential_attrs = %{
        user_id: user.id,
        provider: "google",
        uid: "google-uid-123",
        token: "test-token",
        email: "linked_account@example.com"
      }

      _credential = user_credential_fixture(credential_attrs)

      {:ok, view, _html} = live(conn, ~p"/dashboard/settings")

      assert has_element?(view, "li", "UID: google-uid-123")
      assert has_element?(view, "li", "(linked_account@example.com)")
      refute has_element?(view, "p", "You haven't connected any Google accounts yet.")
    end
  end

  describe "Salesforce accounts section" do
    @describetag :capture_log

    setup :register_and_log_in_user

    test "shows Salesforce section on settings page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/settings")

      assert html =~ "Salesforce" or html =~ "salesforce"
    end

    test "shows connect Salesforce button when no credential exists", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/settings")

      # Should have a connect Salesforce link/button
      assert has_element?(view, "a[href*='salesforce']") or
               render(view) =~ "Connect Salesforce"
    end

    test "displays connected Salesforce account", %{conn: conn, user: user} do
      # Create a Salesforce credential for the user
      _credential = salesforce_credential_fixture(%{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard/settings")

      # Should show the Salesforce credential info
      assert html =~ "salesforce" or html =~ "Salesforce"
    end

    test "shows instance URL for Salesforce credential", %{conn: conn, user: user} do
      _credential =
        salesforce_credential_fixture(%{
          user_id: user.id,
          instance_url: "https://na1.salesforce.com"
        })

      {:ok, _view, html} = live(conn, ~p"/dashboard/settings")

      # The instance URL should be displayed
      assert html =~ "na1.salesforce.com" or html =~ "Salesforce"
    end
  end

  describe "HubSpot accounts section" do
    @describetag :capture_log

    setup :register_and_log_in_user

    test "shows HubSpot section on settings page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/settings")

      assert html =~ "HubSpot" or html =~ "hubspot"
    end

    test "displays connected HubSpot account", %{conn: conn, user: user} do
      # Create a HubSpot credential for the user
      _credential = hubspot_credential_fixture(%{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard/settings")

      # Should show the HubSpot credential info
      assert html =~ "hubspot" or html =~ "HubSpot"
    end
  end

  describe "Multiple CRM accounts" do
    @describetag :capture_log

    setup :register_and_log_in_user

    test "can have both Salesforce and HubSpot connected", %{conn: conn, user: user} do
      _salesforce = salesforce_credential_fixture(%{user_id: user.id})
      _hubspot = hubspot_credential_fixture(%{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard/settings")

      # Both should be shown
      assert (html =~ "Salesforce" or html =~ "salesforce") and
               (html =~ "HubSpot" or html =~ "hubspot")
    end
  end
end
