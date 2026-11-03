# frozen_string_literal: true

require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module RssAggregator
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # How Sources are fetched. The User-Agent identifies the aggregator to
    # Source owners; the timeout keeps one slow Source from tying up a worker.
    config.x.source_fetcher.user_agent = ENV.fetch("SOURCE_FETCHER_USER_AGENT", "RSSAggregator/1.0")
    config.x.source_fetcher.timeout = 15

    # Channel metadata for the Aggregate Feed (/feed.rss). Anything left blank
    # falls back to a default: "RSS Aggregator", the app's own URL, and a
    # one-line description.
    config.x.aggregate_feed.title = ENV["AGGREGATE_FEED_TITLE"]
    config.x.aggregate_feed.link = ENV["AGGREGATE_FEED_LINK"]
    config.x.aggregate_feed.description = ENV["AGGREGATE_FEED_DESCRIPTION"]

    # Mission Control (the Solid Queue UI at /jobs) is behind HTTP basic auth.
    # Credentials come from these environment variables, or else from Rails
    # credentials (mission_control.http_basic_auth_user / _password). With
    # neither set, every request to /jobs is refused.
    config.mission_control.jobs.http_basic_auth_user = ENV["MISSION_CONTROL_USER"].presence
    config.mission_control.jobs.http_basic_auth_password = ENV["MISSION_CONTROL_PASSWORD"].presence

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
