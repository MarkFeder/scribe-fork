defmodule SocialScribeWeb.CrmChatComponentTest do
  use SocialScribeWeb.ConnCase

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures
  import SocialScribe.MeetingsFixtures

  describe "CRM Chat component with Salesforce credential" do
    setup %{conn: conn} do
      user = user_fixture()
      salesforce_credential = salesforce_credential_fixture(%{user_id: user.id})
      meeting = meeting_fixture_with_transcript(user)

      %{
        conn: log_in_user(conn, user),
        user: user,
        meeting: meeting,
        salesforce_credential: salesforce_credential
      }
    end

    test "renders CRM chat section on meeting page", %{conn: conn, meeting: meeting} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      assert html =~ "CRM Assistant" or html =~ "crm-chat"
    end

    test "has a chat input field", %{conn: conn, meeting: meeting} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      # Check for the chat input
      assert has_element?(view, "input[type='text']") or has_element?(view, "textarea")
    end
  end

  describe "CRM Chat component with HubSpot credential" do
    setup %{conn: conn} do
      user = user_fixture()
      hubspot_credential = hubspot_credential_fixture(%{user_id: user.id})
      meeting = meeting_fixture_with_transcript(user)

      %{
        conn: log_in_user(conn, user),
        user: user,
        meeting: meeting,
        hubspot_credential: hubspot_credential
      }
    end

    test "renders CRM chat section on meeting page with HubSpot", %{conn: conn, meeting: meeting} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      assert html =~ "CRM Assistant" or html =~ "crm-chat"
    end
  end

  describe "CRM Chat component with both credentials" do
    setup %{conn: conn} do
      user = user_fixture()
      salesforce_credential = salesforce_credential_fixture(%{user_id: user.id})
      hubspot_credential = hubspot_credential_fixture(%{user_id: user.id})
      meeting = meeting_fixture_with_transcript(user)

      %{
        conn: log_in_user(conn, user),
        user: user,
        meeting: meeting,
        salesforce_credential: salesforce_credential,
        hubspot_credential: hubspot_credential
      }
    end

    test "shows chat when both CRM credentials exist", %{conn: conn, meeting: meeting} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      # The CRM chat should be visible
      assert html =~ "CRM" or html =~ "chat" or html =~ "Assistant"
    end
  end

  describe "CRM Chat component without any CRM credentials" do
    setup %{conn: conn} do
      user = user_fixture()
      meeting = meeting_fixture_with_transcript(user)

      %{
        conn: log_in_user(conn, user),
        user: user,
        meeting: meeting
      }
    end

    test "does not show CRM chat section when no CRM credentials", %{
      conn: conn,
      meeting: meeting
    } do
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      # Without CRM credentials, the CRM chat shouldn't appear
      # This might show a connect prompt instead
      refute html =~ "crm-chat-container" and html =~ "Ask about"
    end
  end

  # Helper function to create a meeting with transcript for testing
  defp meeting_fixture_with_transcript(user) do
    meeting = meeting_fixture(%{})

    # Update the meeting's calendar_event to belong to the test user
    calendar_event = SocialScribe.Calendar.get_calendar_event!(meeting.calendar_event_id)

    {:ok, _updated_event} =
      SocialScribe.Calendar.update_calendar_event(calendar_event, %{user_id: user.id})

    # Create a transcript with some content
    meeting_transcript_fixture(%{
      meeting_id: meeting.id,
      content: %{
        "data" => [
          %{
            "speaker" => "John Doe",
            "words" => [
              %{"text" => "Hello,"},
              %{"text" => "I"},
              %{"text" => "work"},
              %{"text" => "at"},
              %{"text" => "Acme"},
              %{"text" => "Corp."}
            ]
          },
          %{
            "speaker" => "Jane Smith",
            "words" => [
              %{"text" => "Great,"},
              %{"text" => "my"},
              %{"text" => "email"},
              %{"text" => "is"},
              %{"text" => "jane@example.com"}
            ]
          }
        ]
      }
    })

    # Reload the meeting with all associations
    SocialScribe.Meetings.get_meeting_with_details(meeting.id)
  end
end
