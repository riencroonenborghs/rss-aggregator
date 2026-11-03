# frozen_string_literal: true

require "rails_helper"

# Removing a Source, verified by running the remover and then checking the
# remaining Entries and /feed.rss.
RSpec.describe SourceRemover, type: :request do
  let(:source_a) { Source.create!(url: "https://a.example.com/feed.xml", name: "A") }
  let(:source_b) { Source.create!(url: "https://b.example.com/feed.xml", name: "B") }
  let(:source_c) { Source.create!(url: "https://c.example.com/feed.xml", name: "C") }

  def create_entry(source, title, first_seen_at: Time.current, duplicate_of: nil)
    source.entries.create!(identifier: title, title: title, published_at: 1.day.ago,
      first_seen_at: first_seen_at, duplicate_of: duplicate_of)
  end

  def feed_items
    get "/feed.rss"
    Nokogiri::XML(response.body).xpath("/rss/channel/item").map do |item|
      [ item.at_xpath("title").text, item.at_xpath("source").text ]
    end
  end

  it "deletes the Source and its Entries and leaves other Sources' Entries untouched" do
    create_entry(source_a, "A story")
    b_story = create_entry(source_b, "B story")

    removal = described_class.perform(source_a)

    expect(Source.exists?(source_a.id)).to be(false)
    expect(removal.deleted_entries_count).to eq(1)
    expect(removal.promoted_count).to eq(0)
    expect(Entry.all).to eq([ b_story ])
    expect(b_story.reload).to be_original
  end

  it "promotes the earliest-seen Duplicate and re-points the other Duplicates to it" do
    original = create_entry(source_a, "Story in A", first_seen_at: 3.hours.ago)
    earliest = create_entry(source_b, "Story in B", first_seen_at: 2.hours.ago, duplicate_of: original)
    later = create_entry(source_c, "Story in C", first_seen_at: 1.hour.ago, duplicate_of: original)

    removal = described_class.perform(source_a)

    expect(removal.promoted_count).to eq(1)
    expect(earliest.reload).to be_original
    expect(later.reload.duplicate_of).to eq(earliest)
  end

  it "shows the promoted Entry in /feed.rss in place of the removed one, and nothing from the removed Source" do
    original = create_entry(source_a, "Story in A", first_seen_at: 3.hours.ago)
    create_entry(source_b, "Story in B", first_seen_at: 2.hours.ago, duplicate_of: original)
    create_entry(source_c, "Story in C", first_seen_at: 1.hour.ago, duplicate_of: original)
    create_entry(source_a, "Only in A")
    expect(feed_items).to contain_exactly([ "Story in A", "A" ], [ "Only in A", "A" ])

    described_class.perform(source_a)

    expect(feed_items).to eq([ [ "Story in B", "B" ] ])
  end

  it "makes a remaining Duplicate from the promoted Entry's own Source an Original too" do
    original = create_entry(source_a, "Story in A", first_seen_at: 3.hours.ago)
    b_first = create_entry(source_b, "Story in B", first_seen_at: 2.hours.ago, duplicate_of: original)
    b_second = create_entry(source_b, "Story in B again", first_seen_at: 1.hour.ago, duplicate_of: original)

    removal = described_class.perform(source_a)

    expect(removal.promoted_count).to eq(2)
    expect([ b_first.reload, b_second.reload ]).to all(be_original)
    expect(Entry.all).to all(be_valid)
  end

  it "leaves the Originals of the removed Source's Duplicates alone" do
    b_original = create_entry(source_b, "Story in B")
    create_entry(source_a, "Copy in A", duplicate_of: b_original)

    described_class.perform(source_a)

    expect(Entry.all).to eq([ b_original ])
    expect(b_original.reload).to be_original
  end
end
