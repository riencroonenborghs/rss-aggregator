# frozen_string_literal: true

Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Solid Queue UI, behind HTTP basic auth (see config/application.rb).
  mount MissionControl::Jobs::Engine, at: "/jobs"

  get "feed" => "aggregate_feeds#show", as: :aggregate_feed, format: true, constraints: { format: :rss }
end
