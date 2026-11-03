# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Solid Queue UI at /jobs", type: :request do
  def with_credentials(user, password)
    previous = [ MissionControl::Jobs.http_basic_auth_user, MissionControl::Jobs.http_basic_auth_password ]
    MissionControl::Jobs.http_basic_auth_user = user
    MissionControl::Jobs.http_basic_auth_password = password
    yield
  ensure
    MissionControl::Jobs.http_basic_auth_user, MissionControl::Jobs.http_basic_auth_password = previous
  end

  def basic_auth(user, password)
    { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(user, password) }
  end

  it "refuses every request when no credentials are configured" do
    with_credentials(nil, nil) do
      get "/jobs", headers: basic_auth("admin", "")

      expect(response).to have_http_status(:unauthorized)
    end
  end

  it "asks for credentials when none are given" do
    with_credentials("admin", "secret") do
      get "/jobs"

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["WWW-Authenticate"]).to start_with("Basic")
    end
  end

  it "refuses wrong credentials" do
    with_credentials("admin", "secret") do
      get "/jobs", headers: basic_auth("admin", "wrong")

      expect(response).to have_http_status(:unauthorized)
    end
  end

  it "leaves the Aggregate Feed public" do
    with_credentials("admin", "secret") do
      get "/feed.rss"

      expect(response).to have_http_status(:ok)
    end
  end
end
