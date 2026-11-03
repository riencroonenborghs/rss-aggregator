# frozen_string_literal: true

require "rails_helper"

# Retention, verified by running the pruner and then checking what's left in
# the database and in /feed.rss.
RSpec.describe EntryPruner, type: :request do
  let(:source_a) { Source.create!(url: "https://a.example.com/feed.xml", name: "A") }
  let(:source_b) { Source.create!(url: "https://b.example.com/feed.xml", name: "B") }

  def create_entry(source, title, published_at:, duplicate_of: nil)
    source.entries.create!(identifier: title, title: title, published_at: published_at,
      first_seen_at: published_at, duplicate_of: duplicate_of)
  end

  def feed_titles
    get "/feed.rss"
    Nokogiri::XML(response.body).xpath("/rss/channel/item/title").map(&:text)
  end

  it "deletes Entries published more than 30 days ago and keeps newer ones" do
    create_entry(source_a, "Expired", published_at: 31.days.ago)
    create_entry(source_a, "Just expired", published_at: 30.days.ago - 1.minute)
    create_entry(source_a, "Nearly expired", published_at: 30.days.ago + 1.minute)
    create_entry(source_a, "Fresh", published_at: 1.day.ago)

    pruner = described_class.perform

    expect(pruner.deleted_count).to eq(2)
    expect(Entry.pluck(:title)).to contain_exactly("Nearly expired", "Fresh")
  end

  it "deletes an expired Original together with its Duplicates, even newer ones" do
    original = create_entry(source_a, "Original", published_at: 31.days.ago)
    create_entry(source_b, "Late Duplicate", published_at: 29.days.ago, duplicate_of: original)
    create_entry(source_a, "Unrelated", published_at: 1.day.ago)

    described_class.perform

    expect(Entry.pluck(:title)).to eq([ "Unrelated" ])
  end

  it "deletes an expired Duplicate but keeps its fresh Original" do
    original = create_entry(source_a, "Original", published_at: 20.days.ago)
    create_entry(source_b, "Old Duplicate", published_at: 31.days.ago, duplicate_of: original)

    described_class.perform

    expect(Entry.pluck(:title)).to eq([ "Original" ])
  end

  it "removes deleted Entries from /feed.rss" do
    create_entry(source_a, "Expired", published_at: 31.days.ago)
    create_entry(source_a, "Fresh", published_at: 1.day.ago)
    expect(feed_titles).to eq([ "Fresh", "Expired" ])

    described_class.perform

    expect(feed_titles).to eq([ "Fresh" ])
  end

  it "does nothing when no Entry has expired" do
    create_entry(source_a, "Fresh", published_at: 1.day.ago)

    expect(described_class.perform.deleted_count).to eq(0)
    expect(Entry.count).to eq(1)
  end
end
