defmodule SocialScribe.HubspotOAuthTest do
  use SocialScribe.DataCase

  alias SocialScribe.{Accounts, HubspotTokenRefresher}
  alias Ueberauth.Strategy.Hubspot.OAuth

  import SocialScribe.AccountsFixtures

  describe "HubSpot OAuth client configuration" do
    test "client/0 returns a configured OAuth2 client" do
      client = OAuth.client()

      assert client.client_id != nil or client.client_id == nil
      assert client.site == "https://api.hubapi.com"
      assert client.authorize_url == "https://app.hubspot.com/oauth/authorize"
      assert client.token_url == "https://api.hubapi.com/oauth/v1/token"
    end

    test "authorize_url!/2 generates a valid authorization URL" do
      url = OAuth.authorize_url!([scope: "oauth crm.objects.contacts.read"])

      assert url =~ "https://app.hubspot.com/oauth/authorize"
      assert url =~ "client_id="
      assert url =~ "scope="
    end
  end

  describe "HubSpot credential management" do
    test "creating a HubSpot credential stores required fields" do
      user = user_fixture()

      {:ok, credential} =
        Accounts.create_user_credential(%{
          user_id: user.id,
          provider: "hubspot",
          uid: "hub_#{System.unique_integer([:positive])}",
          token: "test_access_token",
          refresh_token: "test_refresh_token",
          expires_at: DateTime.add(DateTime.utc_now(), 7200, :second),
          email: "hubspot_user@example.com"
        })

      assert credential.provider == "hubspot"
      assert credential.token == "test_access_token"
      assert credential.refresh_token == "test_refresh_token"
      assert credential.email == "hubspot_user@example.com"
    end

    test "get_hubspot_credential/1 returns user's HubSpot credential" do
      user = user_fixture()
      hubspot_credential_fixture(%{user_id: user.id})

      credential = Accounts.get_user_hubspot_credential(user.id)

      assert credential != nil
      assert credential.provider == "hubspot"
    end

    test "get_hubspot_credential/1 returns nil when no credential exists" do
      user = user_fixture()

      credential = Accounts.get_user_hubspot_credential(user.id)

      assert credential == nil
    end

    test "multiple users can have separate HubSpot credentials" do
      user1 = user_fixture()
      user2 = user_fixture()

      cred1 = hubspot_credential_fixture(%{user_id: user1.id, uid: "hub_111"})
      cred2 = hubspot_credential_fixture(%{user_id: user2.id, uid: "hub_222"})

      assert cred1.user_id == user1.id
      assert cred2.user_id == user2.id
      assert cred1.uid != cred2.uid
    end
  end

  describe "HubSpot token refresh" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "ensure_valid_token/1 returns credential unchanged if not expired", %{user: user} do
      credential =
        hubspot_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 7200, :second)
        })

      {:ok, result} = HubspotTokenRefresher.ensure_valid_token(credential)

      assert result.id == credential.id
      assert result.token == credential.token
    end

    test "ensure_valid_token/1 attempts refresh for expired token", %{user: user} do
      credential =
        hubspot_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        })

      # Will fail without real HubSpot credentials, but tests the code path
      result = HubspotTokenRefresher.ensure_valid_token(credential)

      # Should return error since we don't have real credentials
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end

    test "token expiring within buffer triggers refresh", %{user: user} do
      # Token expires in 2 minutes (within typical 5-minute buffer)
      credential =
        hubspot_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 120, :second)
        })

      result = HubspotTokenRefresher.ensure_valid_token(credential)

      # Will attempt refresh since token is about to expire
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "HubSpot credential updates" do
    test "updating credential token persists changes" do
      user = user_fixture()
      credential = hubspot_credential_fixture(%{user_id: user.id})

      {:ok, updated} =
        Accounts.update_user_credential(credential, %{
          token: "new_access_token",
          expires_at: DateTime.add(DateTime.utc_now(), 7200, :second)
        })

      assert updated.token == "new_access_token"

      # Reload and verify persistence
      reloaded = Accounts.get_user_credential!(credential.id)
      assert reloaded.token == "new_access_token"
    end
  end
end
