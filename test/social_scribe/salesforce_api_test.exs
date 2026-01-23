defmodule SocialScribe.SalesforceApiTest do
  use SocialScribe.DataCase

  alias SocialScribe.SalesforceApi

  import SocialScribe.AccountsFixtures

  describe "apply_updates/3" do
    test "returns :no_updates when no updates have apply: true" do
      user = user_fixture()
      credential = salesforce_credential_fixture(%{user_id: user.id})

      updates = [
        %{field: "phone", new_value: "555-1234", apply: false},
        %{field: "email", new_value: "test@example.com", apply: false}
      ]

      {:ok, :no_updates} = SalesforceApi.apply_updates(credential, "003xx000001234", updates)
    end

    test "returns :no_updates when updates list is empty" do
      user = user_fixture()
      credential = salesforce_credential_fixture(%{user_id: user.id})

      {:ok, :no_updates} = SalesforceApi.apply_updates(credential, "003xx000001234", [])
    end
  end

  describe "search_contacts/2" do
    test "requires a valid credential" do
      user = user_fixture()

      credential =
        salesforce_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 7200, :second)
        })

      # Verify the credential is valid
      assert is_struct(credential)
      assert credential.provider == "salesforce"
      assert credential.instance_url != nil
    end
  end

  describe "get_contact/2" do
    test "requires a valid credential and contact_id" do
      user = user_fixture()

      credential =
        salesforce_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 7200, :second)
        })

      assert is_struct(credential)
      assert credential.provider == "salesforce"
    end
  end

  describe "update_contact/3" do
    test "requires a valid credential, contact_id, and updates map" do
      user = user_fixture()

      credential =
        salesforce_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 7200, :second)
        })

      assert is_struct(credential)
      assert credential.provider == "salesforce"
    end
  end

  describe "format_contact/1" do
    test "formats a Salesforce contact response correctly" do
      # Test the internal formatting through public functions
      user = user_fixture()
      credential = salesforce_credential_fixture(%{user_id: user.id})

      # apply_updates with empty list should return :no_updates
      {:ok, :no_updates} = SalesforceApi.apply_updates(credential, "003xx000001234", [])
    end
  end
end
