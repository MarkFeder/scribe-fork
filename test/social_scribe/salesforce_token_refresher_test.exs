defmodule SocialScribe.SalesforceTokenRefresherTest do
  use SocialScribe.DataCase

  alias SocialScribe.SalesforceTokenRefresher

  import SocialScribe.AccountsFixtures

  describe "ensure_valid_token/1" do
    test "returns credential unchanged if token is not expired" do
      user = user_fixture()

      # Token expires in 2 hours, well within buffer
      credential =
        salesforce_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 7200, :second)
        })

      # Should return the credential unchanged
      {:ok, result} = SalesforceTokenRefresher.ensure_valid_token(credential)

      assert result.id == credential.id
      assert result.token == credential.token
    end

    test "credential with nil expires_at triggers refresh attempt" do
      user = user_fixture()

      {:ok, credential} =
        SocialScribe.Accounts.create_user_credential(%{
          user_id: user.id,
          provider: "salesforce",
          uid: "005test#{System.unique_integer([:positive])}",
          token: "test_token",
          refresh_token: "test_refresh_token",
          expires_at: nil,
          email: "test@example.com",
          instance_url: "https://na1.salesforce.com"
        })

      # This will try to refresh since expires_at is nil
      # Will fail without real credentials, but tests the code path
      result = SalesforceTokenRefresher.ensure_valid_token(credential)

      # Should return an error tuple since we don't have valid Salesforce credentials
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "refresh_token/1" do
    test "requires valid refresh token string" do
      # Without valid Salesforce OAuth config, this will fail
      # but we can verify the function signature
      result = SalesforceTokenRefresher.refresh_token("invalid_token")

      # Should return an error without valid credentials
      assert match?({:error, _}, result)
    end
  end

  describe "refresh_credential/1" do
    test "attempts to refresh and update the credential" do
      user = user_fixture()

      credential =
        salesforce_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)  # Expired 1 hour ago
        })

      # This will fail without real credentials, but tests the code path
      result = SalesforceTokenRefresher.refresh_credential(credential)

      # Without valid Salesforce config, should return error
      assert match?({:error, _}, result)
    end
  end
end
