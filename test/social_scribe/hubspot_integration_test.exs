defmodule SocialScribe.HubspotIntegrationTest do
  use SocialScribe.DataCase

  alias SocialScribe.{HubspotApi, HubspotSuggestions}

  import SocialScribe.AccountsFixtures

  describe "HubSpot suggestion generation" do
    test "merge_with_contact/2 correctly identifies changes" do
      suggestions = [
        %{
          field: "phone",
          label: "Phone",
          current_value: nil,
          new_value: "555-9999",
          context: "Mentioned new phone number",
          apply: false,
          has_change: true
        },
        %{
          field: "jobtitle",
          label: "Job Title",
          current_value: nil,
          new_value: "Senior VP of Sales",
          context: "Got promoted",
          apply: false,
          has_change: true
        },
        %{
          field: "email",
          label: "Email",
          current_value: nil,
          new_value: "john@example.com",
          context: "Same email",
          apply: false,
          has_change: true
        }
      ]

      contact = %{
        id: "123",
        phone: "555-1234",
        jobtitle: "VP of Sales",
        email: "john@example.com"
      }

      result = HubspotSuggestions.merge_with_contact(suggestions, contact)

      # Only phone and jobtitle should have changes (email is the same)
      assert length(result) == 2

      phone_suggestion = Enum.find(result, &(&1.field == "phone"))
      assert phone_suggestion != nil
      assert phone_suggestion.current_value == "555-1234"
      assert phone_suggestion.new_value == "555-9999"

      jobtitle_suggestion = Enum.find(result, &(&1.field == "jobtitle"))
      assert jobtitle_suggestion != nil
      assert jobtitle_suggestion.current_value == "VP of Sales"
      assert jobtitle_suggestion.new_value == "Senior VP of Sales"
    end

    test "merge_with_contact/2 handles nil current values" do
      suggestions = [
        %{
          field: "phone",
          label: "Phone",
          current_value: nil,
          new_value: "555-9999",
          context: "New phone",
          apply: false,
          has_change: true
        }
      ]

      contact = %{
        id: "123",
        phone: nil
      }

      result = HubspotSuggestions.merge_with_contact(suggestions, contact)

      assert length(result) == 1
      assert hd(result).current_value == nil
      assert hd(result).new_value == "555-9999"
    end

    test "merge_with_contact/2 detects when email values match exactly" do
      suggestions = [
        %{
          field: "email",
          label: "Email",
          current_value: nil,
          new_value: "john@example.com",
          context: "Email mentioned",
          apply: false,
          has_change: true
        }
      ]

      contact = %{
        id: "123",
        email: "john@example.com"
      }

      result = HubspotSuggestions.merge_with_contact(suggestions, contact)

      # Should be empty since emails match exactly
      assert result == []
    end

    test "merge_with_contact/2 identifies change when emails differ" do
      suggestions = [
        %{
          field: "email",
          label: "Email",
          current_value: nil,
          new_value: "john.smith@newcompany.com",
          context: "New email mentioned",
          apply: false,
          has_change: true
        }
      ]

      contact = %{
        id: "123",
        email: "john@oldcompany.com"
      }

      result = HubspotSuggestions.merge_with_contact(suggestions, contact)

      # Should have the email change
      assert length(result) == 1
      assert hd(result).field == "email"
      assert hd(result).current_value == "john@oldcompany.com"
      assert hd(result).new_value == "john.smith@newcompany.com"
    end
  end

  describe "apply_updates/3" do
    setup do
      user = user_fixture()
      credential = hubspot_credential_fixture(%{user_id: user.id})
      %{credential: credential}
    end

    test "returns :no_updates when all updates have apply: false", %{credential: credential} do
      updates = [
        %{field: "phone", new_value: "555-1234", apply: false},
        %{field: "email", new_value: "test@example.com", apply: false}
      ]

      result = HubspotApi.apply_updates(credential, "123", updates)

      assert result == {:ok, :no_updates}
    end

    test "returns :no_updates for empty updates list", %{credential: credential} do
      result = HubspotApi.apply_updates(credential, "123", [])

      assert result == {:ok, :no_updates}
    end
  end

  describe "HubSpot credential operations" do
    setup do
      user = user_fixture()
      credential = hubspot_credential_fixture(%{user_id: user.id})
      %{user: user, credential: credential}
    end

    test "credential has required fields", %{credential: credential} do
      assert credential.provider == "hubspot"
      assert credential.token != nil
      assert credential.refresh_token != nil
    end

    test "credential expires_at is in the future", %{credential: credential} do
      assert DateTime.compare(credential.expires_at, DateTime.utc_now()) == :gt
    end
  end

  describe "multiple suggestion scenarios" do
    test "handles multiple field updates for same contact" do
      suggestions = [
        %{field: "phone", label: "Phone", current_value: nil, new_value: "555-1111", context: "Phone", apply: false, has_change: true},
        %{field: "mobilephone", label: "Mobile", current_value: nil, new_value: "555-2222", context: "Mobile", apply: false, has_change: true},
        %{field: "jobtitle", label: "Job Title", current_value: nil, new_value: "CEO", context: "Title", apply: false, has_change: true},
        %{field: "company", label: "Company", current_value: nil, new_value: "New Corp", context: "Company", apply: false, has_change: true}
      ]

      contact = %{
        id: "123",
        phone: nil,
        mobilephone: nil,
        jobtitle: "CTO",
        company: nil
      }

      result = HubspotSuggestions.merge_with_contact(suggestions, contact)

      # All should be present since they're either nil or different
      assert length(result) == 4

      fields = Enum.map(result, & &1.field)
      assert "phone" in fields
      assert "mobilephone" in fields
      assert "jobtitle" in fields
      assert "company" in fields
    end

    test "handles empty suggestions gracefully" do
      contact = %{id: "123", email: "test@example.com"}

      result = HubspotSuggestions.merge_with_contact([], contact)

      assert result == []
    end

    test "handles contact with many nil fields" do
      suggestions = [
        %{field: "phone", label: "Phone", current_value: nil, new_value: "555-1234", context: "Phone", apply: false, has_change: true}
      ]

      contact = %{
        id: "123",
        phone: nil,
        email: nil,
        firstname: nil,
        lastname: nil,
        company: nil
      }

      result = HubspotSuggestions.merge_with_contact(suggestions, contact)

      assert length(result) == 1
      assert hd(result).field == "phone"
    end
  end
end
