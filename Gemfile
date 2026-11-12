# frozen_string_literal: true

source "https://rubygems.org"

gem "bootsnap", require: false
gem "cssbundling-rails"
gem "feedjira"
gem "httparty"
gem "image_processing", "~> 1.2"
gem "io-console", "0.9.4"
gem "jbuilder"
gem "jsbundling-rails"
gem "mission_control-jobs"
gem "propshaft"
gem "rails_semantic_logger"
gem "puma", ">= 5.0"
gem "rails", "~> 8.1.4.1"
gem "rspec-rails", "~> 8.1"
gem "solid_cable"
gem "solid_cache"
gem "solid_queue"
gem "sqlite3", ">= 2.1"
gem "stimulus-rails"
gem "turbo-rails"
gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  gem "annotaterb", "~> 4.26"
  gem "awesome_print", "~> 1.9"
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"

  # Deployment
  gem "bcrypt_pbkdf", "~> 1.1"
  gem "capistrano"
  gem "capistrano3-puma", "~> 7.1"
  gem "capistrano-bundler"
  gem "capistrano-nvm", require: false
  gem "capistrano-rails"
  gem "capistrano-rbenv"
  gem "ed25519", "~> 1.4"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "webmock"
end
