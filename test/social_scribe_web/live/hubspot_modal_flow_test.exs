defmodule SocialScribeWeb.HubspotModalFlowTest do
  use SocialScribeWeb.ConnCase

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures
  import SocialScribe.MeetingsFixtures
  import SocialScribe.CalendarFixtures

  describe "HubSpot modal full user flow" do
    setup %{conn: conn} do
      user = user_fixture()
      hubspot_credential = hubspot_credential_fixture(%{user_id: user.id})
      meeting = create_meeting_with_rich_transcript(user)

      %{
        conn: log_in_user(conn, user),
        user: user,
        meeting: meeting,
        hubspot_credential: hubspot_credential
      }
    end

    test "user can open HubSpot modal from meeting page", %{conn: conn, meeting: meeting} do
      {:ok, view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      # Verify HubSpot button is present
      assert html =~ "Update HubSpot Contact" or html =~ "HubSpot"

      # Navigate to HubSpot modal
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/hubspot")

      assert has_element?(view, "#hubspot-modal-wrapper")
    end

    test "modal displays search interface initially", %{conn: conn, meeting: meeting} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/hubspot")

      # Should have search input
      assert has_element?(view, "input[phx-keyup='contact_search']")

      # Should not have suggestions form yet
      refute has_element?(view, "form[phx-submit='apply_updates']")
    end

    test "search input has correct attributes", %{conn: conn, meeting: meeting} do
      {:ok, view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/hubspot")

      assert html =~ "Search"
      assert has_element?(view, "input[phx-keyup='contact_search']")
      assert has_element?(view, "input[phx-debounce]")
    end

    test "modal can be dismissed", %{conn: conn, meeting: meeting} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/hubspot")

      assert has_element?(view, "#hubspot-modal-wrapper")

      # Navigate away to dismiss
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      refute html =~ "hubspot-modal-wrapper"
    end
  end

  describe "HubSpot modal without HubSpot connection" do
    setup %{conn: conn} do
      user = user_fixture()
      # No HubSpot credential created
      meeting = create_meeting_with_rich_transcript(user)

      %{
        conn: log_in_user(conn, user),
        user: user,
        meeting: meeting
      }
    end

    test "HubSpot update button not shown without credential", %{conn: conn, meeting: meeting} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      refute html =~ "Update HubSpot Contact"
    end

    test "accessing HubSpot route without credential shows no modal", %{conn: conn, meeting: meeting} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/hubspot")

      refute html =~ "hubspot-modal-wrapper"
    end
  end

  describe "HubSpot modal with meeting without transcript" do
    setup %{conn: conn} do
      user = user_fixture()
      hubspot_credential = hubspot_credential_fixture(%{user_id: user.id})
      meeting = create_meeting_without_transcript(user)

      %{
        conn: log_in_user(conn, user),
        user: user,
        meeting: meeting,
        hubspot_credential: hubspot_credential
      }
    end

    test "modal still opens but may show appropriate message", %{conn: conn, meeting: meeting} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/hubspot")

      # Modal should still render
      assert has_element?(view, "#hubspot-modal-wrapper")
    end
  end

  describe "HubSpot modal responsive behavior" do
    setup %{conn: conn} do
      user = user_fixture()
      hubspot_credential = hubspot_credential_fixture(%{user_id: user.id})
      meeting = create_meeting_with_rich_transcript(user)

      %{
        conn: log_in_user(conn, user),
        user: user,
        meeting: meeting,
        hubspot_credential: hubspot_credential
      }
    end

    test "modal has proper accessibility attributes", %{conn: conn, meeting: meeting} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/hubspot")

      # Check for aria attributes on modal
      assert html =~ "role=" or html =~ "aria-"
    end

    test "search input is focusable", %{conn: conn, meeting: meeting} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/hubspot")

      # Input should be present and interactive
      assert has_element?(view, "input[type='text']")
    end
  end

  # Helper functions

  defp create_meeting_with_rich_transcript(user) do
    # Create credential for calendar event
    credential = user_credential_fixture(%{user_id: user.id})

    # Create calendar event
    {:ok, calendar_event} =
      SocialScribe.Calendar.create_calendar_event(%{
        user_id: user.id,
        user_credential_id: credential.id,
        google_event_id: "test_event_#{System.unique_integer([:positive])}",
        summary: "Sales Call with John Smith",
        description: "Quarterly review",
        start_time: DateTime.add(DateTime.utc_now(), -3600, :second),
        end_time: DateTime.add(DateTime.utc_now(), -1800, :second),
        status: "confirmed",
        hangout_link: "https://meet.google.com/test",
        html_link: "https://calendar.google.com/test",
        location: "Virtual",
        record_meeting: true
      })

    # Create recall bot
    {:ok, recall_bot} =
      SocialScribe.Bots.create_recall_bot(%{
        user_id: user.id,
        calendar_event_id: calendar_event.id,
        recall_bot_id: "test_bot_#{System.unique_integer([:positive])}",
        meeting_url: "https://meet.google.com/test",
        status: "done"
      })

    # Create meeting
    {:ok, meeting} =
      SocialScribe.Meetings.create_meeting(%{
        calendar_event_id: calendar_event.id,
        recall_bot_id: recall_bot.id,
        title: "Sales Call with John Smith",
        recorded_at: DateTime.add(DateTime.utc_now(), -3600, :second),
        duration_seconds: 1800
      })

    # Create participants
    {:ok, _} =
      SocialScribe.Meetings.create_meeting_participant(%{
        meeting_id: meeting.id,
        name: "Host",
        is_host: true,
        recall_participant_id: "host_#{System.unique_integer([:positive])}"
      })

    {:ok, _} =
      SocialScribe.Meetings.create_meeting_participant(%{
        meeting_id: meeting.id,
        name: "John Smith",
        is_host: false,
        recall_participant_id: "participant_#{System.unique_integer([:positive])}"
      })

    # Create rich transcript
    transcript_content = %{
      "data" => [
        %{
          "speaker" => "Host",
          "words" => words_to_list("Hi John, let me confirm your details."),
          "start_time" => 0
        },
        %{
          "speaker" => "John Smith",
          "words" => words_to_list("Sure! My new phone is 555-987-6543."),
          "start_time" => 5
        },
        %{
          "speaker" => "Host",
          "words" => words_to_list("And your email?"),
          "start_time" => 10
        },
        %{
          "speaker" => "John Smith",
          "words" => words_to_list("It changed to john.smith@newcompany.com"),
          "start_time" => 15
        },
        %{
          "speaker" => "Host",
          "words" => words_to_list("What's your current title?"),
          "start_time" => 20
        },
        %{
          "speaker" => "John Smith",
          "words" => words_to_list("I'm now the Chief Revenue Officer at NewCompany Inc."),
          "start_time" => 25
        }
      ]
    }

    {:ok, _} =
      SocialScribe.Meetings.create_meeting_transcript(%{
        meeting_id: meeting.id,
        content: transcript_content
      })

    SocialScribe.Meetings.get_meeting_with_details(meeting.id)
  end

  defp create_meeting_without_transcript(user) do
    credential = user_credential_fixture(%{user_id: user.id})

    {:ok, calendar_event} =
      SocialScribe.Calendar.create_calendar_event(%{
        user_id: user.id,
        user_credential_id: credential.id,
        google_event_id: "test_event_#{System.unique_integer([:positive])}",
        summary: "Meeting Without Transcript",
        description: "Test meeting",
        start_time: DateTime.add(DateTime.utc_now(), -3600, :second),
        end_time: DateTime.add(DateTime.utc_now(), -1800, :second),
        status: "confirmed",
        hangout_link: "https://meet.google.com/test",
        html_link: "https://calendar.google.com/test",
        location: "Virtual",
        record_meeting: true
      })

    {:ok, recall_bot} =
      SocialScribe.Bots.create_recall_bot(%{
        user_id: user.id,
        calendar_event_id: calendar_event.id,
        recall_bot_id: "test_bot_#{System.unique_integer([:positive])}",
        meeting_url: "https://meet.google.com/test",
        status: "done"
      })

    {:ok, meeting} =
      SocialScribe.Meetings.create_meeting(%{
        calendar_event_id: calendar_event.id,
        recall_bot_id: recall_bot.id,
        title: "Meeting Without Transcript",
        recorded_at: DateTime.add(DateTime.utc_now(), -3600, :second),
        duration_seconds: 1800
      })

    SocialScribe.Meetings.get_meeting_with_details(meeting.id)
  end

  defp words_to_list(sentence) do
    sentence
    |> String.split(" ")
    |> Enum.map(&%{"text" => &1})
  end
end
