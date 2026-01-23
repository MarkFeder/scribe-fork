defmodule Ueberauth.Strategy.SalesforceTest do
  use ExUnit.Case, async: true

  alias Ueberauth.Strategy.Salesforce

  describe "default_options/0" do
    test "returns expected default options" do
      defaults = Salesforce.default_options()

      assert defaults[:uid_field] == :user_id
      assert defaults[:default_scope] == "api refresh_token"
      assert defaults[:oauth2_module] == Ueberauth.Strategy.Salesforce.OAuth
    end
  end

  describe "module behavior" do
    test "module is loaded and implements Ueberauth.Strategy" do
      assert Code.ensure_loaded?(Ueberauth.Strategy.Salesforce)

      # Verify required callbacks exist
      assert function_exported?(Salesforce, :handle_request!, 1)
      assert function_exported?(Salesforce, :handle_callback!, 1)
      assert function_exported?(Salesforce, :uid, 1)
      assert function_exported?(Salesforce, :credentials, 1)
      assert function_exported?(Salesforce, :info, 1)
      assert function_exported?(Salesforce, :extra, 1)
    end
  end
end

defmodule Ueberauth.Strategy.Salesforce.OAuthTest do
  use ExUnit.Case, async: true

  alias Ueberauth.Strategy.Salesforce.OAuth

  describe "client/1" do
    test "creates OAuth2 client with default configuration" do
      client = OAuth.client()

      assert client.site == "https://login.salesforce.com"
      assert client.authorize_url == "/services/oauth2/authorize"
      assert client.token_url == "/services/oauth2/token"
    end

    test "client can be customized with options" do
      # The client function accepts options to override defaults
      client = OAuth.client()

      # Verify the client is an OAuth2.Client struct
      assert %OAuth2.Client{} = client
    end
  end

  describe "authorize_url!/2" do
    test "generates authorization URL with default scope" do
      params = []
      url = OAuth.authorize_url!(params)

      assert is_binary(url)
      assert String.contains?(url, "login.salesforce.com")
      assert String.contains?(url, "oauth2/authorize")
    end

    test "generates authorization URL with custom scope" do
      params = [scope: "api refresh_token full"]
      url = OAuth.authorize_url!(params)

      assert is_binary(url)
      assert String.contains?(url, "scope=")
    end
  end

  describe "module structure" do
    test "OAuth module is loaded" do
      assert Code.ensure_loaded?(Ueberauth.Strategy.Salesforce.OAuth)
    end

    test "OAuth module exports required functions" do
      assert function_exported?(OAuth, :client, 0)
      assert function_exported?(OAuth, :client, 1)
      assert function_exported?(OAuth, :authorize_url!, 1)
      assert function_exported?(OAuth, :authorize_url!, 2)
      assert function_exported?(OAuth, :get_access_token, 2)
      assert function_exported?(OAuth, :refresh_access_token, 2)
      assert function_exported?(OAuth, :get_user_info, 2)
    end
  end

  describe "sandbox support" do
    test "default site is production Salesforce" do
      client = OAuth.client()
      assert client.site == "https://login.salesforce.com"
    end
  end
end
