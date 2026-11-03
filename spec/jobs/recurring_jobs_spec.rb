# frozen_string_literal: true

require "rails_helper"

RSpec.describe "recurring jobs" do
  include ActiveJob::TestHelper

  it "schedules fetching all Sources every 30 minutes in development and production" do
    recurring = ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/recurring.yml"))

    %w[development production].each do |env|
      expect(recurring.dig(env, "fetch_all_sources")).to include("class" => "FetchAllSourcesJob", "schedule" => "every 30 minutes")
    end
  end

  it "enqueues one fetch job per Source" do
    first = Source.create!(url: "https://one.example.com/feed.xml")
    second = Source.create!(url: "https://two.example.com/feed.xml")

    expect { FetchAllSourcesJob.perform_now }
      .to have_enqueued_job(FetchSourceJob).with(first)
      .and have_enqueued_job(FetchSourceJob).with(second)
  end

  it "fetches the Source and records failures instead of raising" do
    source = Source.create!(url: "https://one.example.com/feed.xml")
    stub_request(:get, source.url).to_return(status: 503)

    expect { FetchSourceJob.perform_now(source) }.not_to raise_error
    expect(source.reload.last_error).to include("HTTP 503")
  end

  it "schedules pruning expired Entries daily in development and production" do
    recurring = ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/recurring.yml"))

    %w[development production].each do |env|
      expect(recurring.dig(env, "prune_entries")).to include("class" => "PruneEntriesJob", "schedule" => "every day at 4am")
    end
  end

  it "prunes expired Entries" do
    source = Source.create!(url: "https://one.example.com/feed.xml")
    source.entries.create!(identifier: "old", published_at: 31.days.ago, first_seen_at: 31.days.ago)

    PruneEntriesJob.perform_now

    expect(Entry.count).to eq(0)
  end
end
