# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "sources rake tasks" do
  before(:all) { Rails.application.load_tasks if Rake::Task.tasks.none? { |task| task.name == "sources:add" } }

  let(:url) { "https://blog.example.com/feed.xml" }

  def run(name, *args)
    task = Rake::Task[name]
    task.reenable
    task.invoke(*args)
  end

  def run_add(*args) = run("sources:add", *args)

  describe "sources:add" do
    it "adds the Source, fetches it immediately and reports how many Entries were stored" do
      stub_request(:get, url).to_return(body: file_fixture("feeds/rss2.xml").read)

      expect { run_add(url, "Example Blog") }.to output("Added Example Blog: 2 Entries stored\n").to_stdout

      expect(Source.find_by!(url: url).entries.count).to eq(2)
    end

    it "rejects a URL that is already registered" do
      Source.create!(url: url)

      expect { run_add(url) }.to raise_error(SystemExit).and output(/Url has already been taken/).to_stderr
      expect(Source.count).to eq(1)
    end

    it "reports a failed first fetch" do
      stub_request(:get, url).to_return(status: 404)

      expect { run_add(url) }.to raise_error(SystemExit).and output(/first fetch failed: .*HTTP 404/).to_stderr
      expect(Source.find_by!(url: url).last_error).to include("HTTP 404")
    end
  end

  describe "sources:remove" do
    it "removes the Source and reports what happened" do
      source = Source.create!(url: url, name: "Example Blog")
      original = source.entries.create!(identifier: "a", published_at: 1.day.ago, first_seen_at: 2.hours.ago)
      source.entries.create!(identifier: "b", published_at: 1.day.ago, first_seen_at: 1.hour.ago)
      other = Source.create!(url: "https://other.example.com/feed.xml")
      other.entries.create!(identifier: "c", published_at: 1.day.ago, first_seen_at: 1.hour.ago, duplicate_of: original)

      expect { run("sources:remove", url) }.to output(
        "Removed Example Blog: 2 Entries deleted, 1 Duplicate(s) from other Sources promoted to Original\n"
      ).to_stdout
      expect(Source.pluck(:url)).to eq([ "https://other.example.com/feed.xml" ])
    end

    it "prints a clear message for an unknown URL" do
      expect { run("sources:remove", "https://unknown.example.com/feed.xml") }
        .to raise_error(SystemExit).and output(/No Source with URL "https:\/\/unknown.example.com\/feed.xml"/).to_stderr
    end
  end

  describe "sources:list" do
    it "prints each Source's name, URL, last fetch time, last error and Entry count" do
      healthy = Source.create!(url: url, name: "Healthy", last_fetched_at: Time.utc(2026, 11, 3, 8))
      healthy.entries.create!(identifier: "a", published_at: 1.day.ago, first_seen_at: 1.day.ago)
      healthy.entries.create!(identifier: "b", published_at: 1.day.ago, first_seen_at: 1.day.ago)
      Source.create!(url: "https://broken.example.com/feed.xml", name: "Broken",
        last_error: "SourceFetcher::Error: HTTP 500", last_error_at: Time.utc(2026, 11, 3, 9))

      expect { run("sources:list") }.to output(<<~TEXT).to_stdout
        Broken
          URL:          https://broken.example.com/feed.xml
          Last fetched: never
          Last error:   SourceFetcher::Error: HTTP 500 (2026-11-03 09:00:00)
          Entries:      0
        Healthy
          URL:          https://blog.example.com/feed.xml
          Last fetched: 2026-11-03 08:00:00
          Last error:   none
          Entries:      2
      TEXT
    end
  end
end
