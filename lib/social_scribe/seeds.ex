defmodule SocialScribe.Seeds do
  @moduledoc """
  Seed data for testing purposes.

  Can be run in production via:
    fly ssh console -a <app-name> -C "/app/bin/social_scribe eval 'SocialScribe.Seeds.create_test_meetings(\"user@example.com\")'"

  Or from IEx:
    SocialScribe.Seeds.create_test_meetings("user@example.com")
  """

  import Ecto.Query
  alias SocialScribe.{Repo, Accounts, Calendar, Bots, Meetings}

  @doc """
  Creates test meetings for a user by email.

  ## Examples

      SocialScribe.Seeds.create_test_meetings("user@example.com")
      SocialScribe.Seeds.create_test_meetings("user@example.com", count: 5)
  """
  def create_test_meetings(user_email, opts \\ []) when is_binary(user_email) do
    case Accounts.get_user_by_email(user_email) do
      nil ->
        {:error, "User not found: #{user_email}"}

      user ->
        count = Keyword.get(opts, :count, 4)
        create_meetings_for_user(user, count)
    end
  end

  @doc """
  Creates test meetings for the first user in the database.
  Useful for quick testing.
  """
  def create_test_meetings_for_first_user(opts \\ []) do
    case Repo.one(from u in Accounts.User, limit: 1) do
      nil ->
        {:error, "No users found in database"}

      user ->
        count = Keyword.get(opts, :count, 4)
        create_meetings_for_user(user, count)
    end
  end

  defp create_meetings_for_user(user, count) do
    IO.puts("Creating #{count} test meetings for user: #{user.email}")

    # Get or create a google credential
    credential = get_or_create_google_credential(user)

    meetings_data = [
      %{
        title: "Sales Call with John Smith - Acme Corp",
        description: "Quarterly review meeting",
        participant: "John Smith",
        hours_ago: 1,
        duration: 1800,
        transcript: sales_call_transcript()
      },
      %{
        title: "Product Demo - TechStart Inc",
        description: "Product demonstration for potential customer",
        participant: "Sarah Johnson",
        hours_ago: 2,
        duration: 2700,
        transcript: product_demo_transcript()
      },
      %{
        title: "Partnership Discussion - GlobalTech Solutions",
        description: "Strategic partnership exploration",
        participant: "Mike Chen",
        hours_ago: 24,
        duration: 3600,
        transcript: partnership_transcript()
      },
      %{
        title: "Customer Feedback Session - RetailMax",
        description: "Quarterly feedback from key customer",
        participant: "Emily Davis",
        hours_ago: 48,
        duration: 1800,
        transcript: feedback_transcript()
      },
      %{
        title: "Investor Update Call - Q4 Review",
        description: "Quarterly investor update",
        participant: "David Park",
        hours_ago: 72,
        duration: 2400,
        transcript: investor_transcript()
      },
      %{
        title: "Technical Architecture Review",
        description: "System architecture discussion",
        participant: "Lisa Wang",
        hours_ago: 96,
        duration: 3000,
        transcript: technical_transcript()
      }
    ]

    created =
      meetings_data
      |> Enum.take(count)
      |> Enum.map(fn data ->
        case create_single_meeting(user, credential, data) do
          {:ok, meeting} ->
            IO.puts("  Created: #{meeting.title} (ID: #{meeting.id})")
            meeting

          {:error, reason} ->
            IO.puts("  Failed: #{data.title} - #{inspect(reason)}")
            nil
        end
      end)
      |> Enum.filter(& &1)

    IO.puts("\nCreated #{length(created)} test meetings!")
    IO.puts("\nMeeting URLs:")
    Enum.each(created, fn m ->
      IO.puts("  /dashboard/meetings/#{m.id} - #{m.title}")
    end)

    {:ok, created}
  end

  defp get_or_create_google_credential(user) do
    case Repo.one(
           from c in Accounts.UserCredential,
             where: c.user_id == ^user.id and c.provider == "google",
             limit: 1
         ) do
      nil ->
        {:ok, cred} =
          Accounts.create_user_credential(%{
            user_id: user.id,
            provider: "google",
            uid: "test_uid_#{System.unique_integer([:positive])}",
            token: "test_token",
            refresh_token: "test_refresh",
            expires_at: DateTime.add(DateTime.utc_now(), 7200, :second),
            email: user.email
          })

        cred

      cred ->
        cred
    end
  end

  defp create_single_meeting(user, credential, data) do
    now = DateTime.utc_now()
    start_time = DateTime.add(now, -data.hours_ago * 3600, :second)
    end_time = DateTime.add(start_time, data.duration, :second)

    with {:ok, calendar_event} <-
           Calendar.create_calendar_event(%{
             user_id: user.id,
             user_credential_id: credential.id,
             google_event_id: "test_event_#{System.unique_integer([:positive])}",
             summary: data.title,
             description: data.description,
             start_time: start_time,
             end_time: end_time,
             status: "confirmed",
             hangout_link: "https://meet.google.com/test-#{System.unique_integer([:positive])}",
             html_link: "https://calendar.google.com/test",
             location: "Virtual",
             record_meeting: true
           }),
         {:ok, recall_bot} <-
           Bots.create_recall_bot(%{
             user_id: user.id,
             calendar_event_id: calendar_event.id,
             recall_bot_id: "test_bot_#{System.unique_integer([:positive])}",
             meeting_url: calendar_event.hangout_link,
             status: "done"
           }),
         {:ok, meeting} <-
           Meetings.create_meeting(%{
             calendar_event_id: calendar_event.id,
             recall_bot_id: recall_bot.id,
             title: data.title,
             recorded_at: start_time,
             duration_seconds: data.duration
           }),
         {:ok, _host} <-
           Meetings.create_meeting_participant(%{
             meeting_id: meeting.id,
             name: "Me (Host)",
             is_host: true,
             recall_participant_id: "host_#{System.unique_integer([:positive])}"
           }),
         {:ok, _participant} <-
           Meetings.create_meeting_participant(%{
             meeting_id: meeting.id,
             name: data.participant,
             is_host: false,
             recall_participant_id: "participant_#{System.unique_integer([:positive])}"
           }),
         {:ok, _transcript} <-
           Meetings.create_meeting_transcript(%{
             meeting_id: meeting.id,
             content: data.transcript
           }) do
      {:ok, meeting}
    end
  end

  defp words_to_list(sentence) do
    sentence
    |> String.split(" ")
    |> Enum.map(fn word -> %{"text" => word} end)
  end

  defp sales_call_transcript do
    %{
      "data" => [
        %{"speaker" => "Me (Host)", "words" => words_to_list("Hi John, thanks for joining the call today. Let me just confirm your details."), "start_time" => 0},
        %{"speaker" => "John Smith", "words" => words_to_list("Sure, happy to be here. I am excited to discuss the partnership."), "start_time" => 5},
        %{"speaker" => "Me (Host)", "words" => words_to_list("Great! So you are the VP of Sales at Acme Corporation, correct?"), "start_time" => 12},
        %{"speaker" => "John Smith", "words" => words_to_list("That is right. Actually, I just got promoted to Senior VP of Sales last month."), "start_time" => 18},
        %{"speaker" => "Me (Host)", "words" => words_to_list("Congratulations! And what is the best number to reach you?"), "start_time" => 25},
        %{"speaker" => "John Smith", "words" => words_to_list("You can reach me at 555-123-4567. That is my direct line."), "start_time" => 30},
        %{"speaker" => "Me (Host)", "words" => words_to_list("Perfect. And your email is still john.smith@acmecorp.com?"), "start_time" => 38},
        %{"speaker" => "John Smith", "words" => words_to_list("Actually, it changed to jsmith@acme-corporation.com with the rebrand."), "start_time" => 44},
        %{"speaker" => "Me (Host)", "words" => words_to_list("Got it, I will update that. Now, about the proposal..."), "start_time" => 52},
        %{"speaker" => "John Smith", "words" => words_to_list("Yes, we are looking at a budget of around 50000 dollars for Q2."), "start_time" => 58}
      ]
    }
  end

  defp product_demo_transcript do
    %{
      "data" => [
        %{"speaker" => "Me (Host)", "words" => words_to_list("Hi Sarah, welcome to the demo! Can you tell me a bit about TechStart?"), "start_time" => 0},
        %{"speaker" => "Sarah Johnson", "words" => words_to_list("Thanks for having me! I am the CTO at TechStart Inc. We are a Series B startup in the fintech space."), "start_time" => 8},
        %{"speaker" => "Me (Host)", "words" => words_to_list("Great! How can I reach you after this call?"), "start_time" => 20},
        %{"speaker" => "Sarah Johnson", "words" => words_to_list("Best way is email at sarah.johnson@techstart.io or my cell 415-555-9876."), "start_time" => 26},
        %{"speaker" => "Me (Host)", "words" => words_to_list("Perfect. Now let me show you our platform features."), "start_time" => 35},
        %{"speaker" => "Sarah Johnson", "words" => words_to_list("I am particularly interested in the API integrations. Our office is at 500 Tech Boulevard, Palo Alto."), "start_time" => 42},
        %{"speaker" => "Me (Host)", "words" => words_to_list("We have great API documentation. What is your timeline for implementation?"), "start_time" => 55},
        %{"speaker" => "Sarah Johnson", "words" => words_to_list("We are looking at Q2 rollout. Budget is around 75000 dollars for this year."), "start_time" => 63}
      ]
    }
  end

  defp partnership_transcript do
    %{
      "data" => [
        %{"speaker" => "Me (Host)", "words" => words_to_list("Mike, thanks for taking the time to discuss this partnership opportunity."), "start_time" => 0},
        %{"speaker" => "Mike Chen", "words" => words_to_list("Of course! I am the Director of Business Development at GlobalTech Solutions."), "start_time" => 7},
        %{"speaker" => "Me (Host)", "words" => words_to_list("Tell me about your company focus areas."), "start_time" => 15},
        %{"speaker" => "Mike Chen", "words" => words_to_list("We specialize in enterprise software. Headquarters in Seattle at 200 Innovation Way."), "start_time" => 21},
        %{"speaker" => "Me (Host)", "words" => words_to_list("How should we follow up after this meeting?"), "start_time" => 32},
        %{"speaker" => "Mike Chen", "words" => words_to_list("Email me at mike.chen@globaltech.com or call my office line 206-555-3344."), "start_time" => 38},
        %{"speaker" => "Me (Host)", "words" => words_to_list("Great. What would an ideal partnership look like for GlobalTech?"), "start_time" => 48},
        %{"speaker" => "Mike Chen", "words" => words_to_list("We are thinking co-marketing and technology integration. Revenue share model preferred."), "start_time" => 55}
      ]
    }
  end

  defp feedback_transcript do
    %{
      "data" => [
        %{"speaker" => "Me (Host)", "words" => words_to_list("Emily, we really value your feedback as one of our top customers."), "start_time" => 0},
        %{"speaker" => "Emily Davis", "words" => words_to_list("Happy to help! As Head of Operations at RetailMax, I use your product daily."), "start_time" => 8},
        %{"speaker" => "Me (Host)", "words" => words_to_list("That is great to hear. What is working well for you?"), "start_time" => 18},
        %{"speaker" => "Emily Davis", "words" => words_to_list("The reporting features are excellent. Our team at 789 Commerce Street, Chicago loves them."), "start_time" => 24},
        %{"speaker" => "Me (Host)", "words" => words_to_list("Any areas for improvement?"), "start_time" => 35},
        %{"speaker" => "Emily Davis", "words" => words_to_list("Mobile app could be better. You can reach me at emily.davis@retailmax.com to discuss more."), "start_time" => 40},
        %{"speaker" => "Me (Host)", "words" => words_to_list("We are working on a mobile update. What is your direct number?"), "start_time" => 52},
        %{"speaker" => "Emily Davis", "words" => words_to_list("My cell is 312-555-7788. Looking forward to the improvements!"), "start_time" => 59}
      ]
    }
  end

  defp investor_transcript do
    %{
      "data" => [
        %{"speaker" => "Me (Host)", "words" => words_to_list("David, thank you for joining our quarterly update call."), "start_time" => 0},
        %{"speaker" => "David Park", "words" => words_to_list("Thanks for the update. I am a Partner at Venture Capital Partners. Excited to hear the progress."), "start_time" => 6},
        %{"speaker" => "Me (Host)", "words" => words_to_list("We have seen 40 percent growth this quarter. Let me walk you through the numbers."), "start_time" => 15},
        %{"speaker" => "David Park", "words" => words_to_list("That is impressive. You can reach me at david.park@vcpartners.com for follow up questions."), "start_time" => 25},
        %{"speaker" => "Me (Host)", "words" => words_to_list("What metrics are you most interested in tracking?"), "start_time" => 35},
        %{"speaker" => "David Park", "words" => words_to_list("ARR and customer retention primarily. My office number is 650-555-2200."), "start_time" => 42},
        %{"speaker" => "Me (Host)", "words" => words_to_list("We will include those in next month report."), "start_time" => 52},
        %{"speaker" => "David Park", "words" => words_to_list("Perfect. Our office is at 100 Sand Hill Road, Menlo Park."), "start_time" => 58}
      ]
    }
  end

  defp technical_transcript do
    %{
      "data" => [
        %{"speaker" => "Me (Host)", "words" => words_to_list("Lisa, thanks for reviewing our architecture proposal."), "start_time" => 0},
        %{"speaker" => "Lisa Wang", "words" => words_to_list("Happy to help. I am the Principal Engineer at CloudScale Systems."), "start_time" => 6},
        %{"speaker" => "Me (Host)", "words" => words_to_list("What do you think about our microservices approach?"), "start_time" => 14},
        %{"speaker" => "Lisa Wang", "words" => words_to_list("It looks solid. I would recommend adding more caching layers. You can email me at lisa.wang@cloudscale.io."), "start_time" => 20},
        %{"speaker" => "Me (Host)", "words" => words_to_list("Great suggestion. Any concerns about scalability?"), "start_time" => 32},
        %{"speaker" => "Lisa Wang", "words" => words_to_list("The database design might need optimization. Call me at 408-555-6677 to discuss further."), "start_time" => 38},
        %{"speaker" => "Me (Host)", "words" => words_to_list("We will schedule a deep dive session."), "start_time" => 50},
        %{"speaker" => "Lisa Wang", "words" => words_to_list("Sounds good. Our engineering office is at 300 Tech Campus Drive, San Jose."), "start_time" => 55}
      ]
    }
  end
end
