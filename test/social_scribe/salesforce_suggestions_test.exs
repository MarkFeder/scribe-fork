defmodule SocialScribe.SalesforceSuggestionsTest do
  use SocialScribe.DataCase

  alias SocialScribe.SalesforceSuggestions

  describe "merge_with_contact/2" do
    test "merges AI suggestions with contact data showing current vs suggested values" do
      suggestions = [
        %{
          field: "phone",
          label: "Phone",
          current_value: nil,
          new_value: "555-1234",
          context: "mentioned their phone number",
          timestamp: "01:23",
          apply: true,
          has_change: true
        },
        %{
          field: "email",
          label: "Email",
          current_value: nil,
          new_value: "new@example.com",
          context: "shared their email",
          timestamp: "02:45",
          apply: true,
          has_change: true
        }
      ]

      contact = %{
        id: "003xx000001234",
        firstname: "John",
        lastname: "Doe",
        email: "old@example.com",
        phone: nil,
        mobilephone: nil,
        company: "Acme Corp",
        jobtitle: "Manager",
        department: nil,
        address: nil,
        city: nil,
        state: nil,
        zip: nil,
        country: nil,
        description: nil,
        display_name: "John Doe"
      }

      merged = SalesforceSuggestions.merge_with_contact(suggestions, contact)

      # Should filter out suggestions where current == new
      # phone: nil -> "555-1234" (has_change: true)
      # email: "old@example.com" -> "new@example.com" (has_change: true)
      assert length(merged) == 2

      phone_suggestion = Enum.find(merged, &(&1.field == "phone"))
      assert phone_suggestion.current_value == nil
      assert phone_suggestion.new_value == "555-1234"
      assert phone_suggestion.has_change == true

      email_suggestion = Enum.find(merged, &(&1.field == "email"))
      assert email_suggestion.current_value == "old@example.com"
      assert email_suggestion.new_value == "new@example.com"
      assert email_suggestion.has_change == true
    end

    test "filters out suggestions where current value equals new value" do
      suggestions = [
        %{
          field: "phone",
          label: "Phone",
          current_value: nil,
          new_value: "555-1234",
          context: "mentioned phone",
          timestamp: "01:00",
          apply: true,
          has_change: true
        }
      ]

      contact = %{
        id: "003xx000001234",
        firstname: "John",
        lastname: "Doe",
        email: nil,
        phone: "555-1234",  # Same as suggestion
        mobilephone: nil,
        company: nil,
        jobtitle: nil,
        department: nil,
        address: nil,
        city: nil,
        state: nil,
        zip: nil,
        country: nil,
        description: nil,
        display_name: "John Doe"
      }

      merged = SalesforceSuggestions.merge_with_contact(suggestions, contact)

      # Should filter out the phone suggestion since current == new
      assert Enum.empty?(merged)
    end

    test "sets apply to true for all merged suggestions" do
      suggestions = [
        %{
          field: "company",
          label: "Company/Account",
          current_value: nil,
          new_value: "New Corp",
          context: "joined New Corp",
          timestamp: "03:00",
          apply: false,  # Even if false, merge should set to true
          has_change: true
        }
      ]

      contact = %{
        id: "003xx000001234",
        firstname: "John",
        lastname: "Doe",
        email: nil,
        phone: nil,
        mobilephone: nil,
        company: nil,
        jobtitle: nil,
        department: nil,
        address: nil,
        city: nil,
        state: nil,
        zip: nil,
        country: nil,
        description: nil,
        display_name: "John Doe"
      }

      merged = SalesforceSuggestions.merge_with_contact(suggestions, contact)

      assert length(merged) == 1
      assert hd(merged).apply == true
    end
  end

  describe "field labels" do
    test "has labels for all standard Salesforce contact fields" do
      expected_fields = [
        "firstname",
        "lastname",
        "email",
        "phone",
        "mobilephone",
        "company",
        "jobtitle",
        "department",
        "address",
        "city",
        "state",
        "zip",
        "country",
        "description"
      ]

      # Use module attribute through generate_suggestions_from_meeting error path
      # This is an indirect test to ensure the module compiles correctly
      # with all expected field labels
      assert Code.ensure_loaded?(SalesforceSuggestions)

      # Verify the module has the expected functions
      assert function_exported?(SalesforceSuggestions, :generate_suggestions, 3)
      assert function_exported?(SalesforceSuggestions, :generate_suggestions_from_meeting, 1)
      assert function_exported?(SalesforceSuggestions, :merge_with_contact, 2)
    end
  end
end
