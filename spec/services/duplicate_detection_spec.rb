# frozen_string_literal: true

require "rails_helper"

# Duplicate detection, verified through the fetch-a-Source seam: each Source
# serves an RSS document, gets fetched, and the stored Entries are checked.
RSpec.describe "Duplicate detection when fetching Sources" do
  let(:source_a) { Source.create!(url: "https://a.example.com/feed.xml", name: "A") }
  let(:source_b) { Source.create!(url: "https://b.example.com/feed.xml", name: "B") }
  let(:source_c) { Source.create!(url: "https://c.example.com/feed.xml", name: "C") }

  # Serves and fetches an RSS document for `source` built from item hashes
  # (keys: guid, title, link, published; published defaults to an hour ago).
  def fetch(source, *items)
    xml = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |x|
      x.rss(version: "2.0") do
        x.channel do
          x.title source.name
          x.link source.url
          x.description "Example"
          items.each do |item|
            x.item do
              x.guid item.fetch(:guid), isPermaLink: "false"
              x.title item.fetch(:title, item[:guid])
              x.link item[:link] if item[:link]
              x.pubDate item.fetch(:published, 1.hour.ago).rfc2822
            end
          end
        end
      end
    end.to_xml
    stub_request(:get, source.url).to_return(body: xml)
    expect(source.fetch).to be_success
  end

  def entry(source, guid) = source.entries.find_by!(identifier: guid)

  describe "matching by normalised link" do
    {
      "a different scheme" => "http://news.example.com/story",
      "a www. prefix" => "https://www.news.example.com/story",
      "an uppercase host" => "https://NEWS.Example.com/story",
      "a trailing slash" => "https://news.example.com/story/",
      "utm_* parameters" => "https://news.example.com/story?utm_source=rss&utm_medium=feed",
      "a fragment" => "https://news.example.com/story#comments"
    }.each do |difference, link_in_b|
      it "marks an Entry from another Source as a Duplicate when its link differs only by #{difference}" do
        fetch(source_a, guid: "a1", link: "https://news.example.com/story")
        fetch(source_b, guid: "b1", link: link_in_b)

        expect(entry(source_b, "b1").duplicate_of).to eq(entry(source_a, "a1"))
        expect(entry(source_a, "a1")).to be_original
      end
    end

    it "keeps other query parameters significant" do
      fetch(source_a, guid: "a1", link: "https://news.example.com/story?id=1")
      fetch(source_b, guid: "b1", link: "https://news.example.com/story?id=2&utm_source=rss")

      expect(entry(source_b, "b1")).to be_original
    end

    it "doesn't match Entries with different links" do
      fetch(source_a, guid: "a1", link: "https://news.example.com/one")
      fetch(source_b, guid: "b1", link: "https://news.example.com/two")

      expect(entry(source_b, "b1")).to be_original
    end

    it "doesn't match Entries that have no link" do
      fetch(source_a, guid: "a1")
      fetch(source_b, guid: "b1")

      expect(entry(source_b, "b1")).to be_original
    end
  end

  describe "matching by fuzzy title" do
    let(:headline) { "Apple announces new MacBook Pro with the M5 chip" }

    it "marks an Entry from another Source as a Duplicate when the titles differ only by case and punctuation" do
      fetch(source_a, guid: "a1", title: headline, published: 2.days.ago)
      fetch(source_b, guid: "b1", title: "Apple Announces New MacBook Pro, With the M5 Chip!", published: 1.day.ago)

      expect(entry(source_b, "b1").duplicate_of).to eq(entry(source_a, "a1"))
    end

    it "marks an Entry from another Source as a Duplicate when the titles differ by one short word" do
      fetch(source_a, guid: "a1", title: headline, published: 2.days.ago)
      fetch(source_b, guid: "b1", title: "Apple announces new MacBook Pro with an M5 chip", published: 1.day.ago)

      expect(entry(source_b, "b1").duplicate_of).to eq(entry(source_a, "a1"))
    end

    it "keeps both as Originals when the titles are just under 90% alike" do
      fetch(source_a, guid: "a1", title: headline, published: 2.days.ago)
      fetch(source_b, guid: "b1", title: "Apple announces cheaper MacBook Pro with the M5 chip", published: 1.day.ago)

      expect(entry(source_b, "b1")).to be_original
    end

    it "keeps both as Originals when they were published more than 3 days apart" do
      fetch(source_a, guid: "a1", title: headline, published: 5.days.ago)
      fetch(source_b, guid: "b1", title: headline, published: 1.day.ago)

      expect(entry(source_b, "b1")).to be_original
    end

    it "matches up to 3 days apart in either direction" do
      fetch(source_a, guid: "a1", title: headline, published: 1.day.ago)
      fetch(source_b, guid: "b1", title: headline, published: 3.days.ago + 1.minute)

      expect(entry(source_b, "b1").duplicate_of).to eq(entry(source_a, "a1"))
    end

    it "keeps short generic titles as Originals even when identical" do
      fetch(source_a, guid: "a1", title: "Weekly links roundup", published: 2.days.ago)
      fetch(source_b, guid: "b1", title: "Weekly links roundup", published: 1.day.ago)

      expect(entry(source_b, "b1")).to be_original
    end

    it "keeps similar titles within the same Source as Originals" do
      fetch(source_a, { guid: "a1", title: headline, published: 2.days.ago },
        { guid: "a2", title: "Apple announces new MacBook Pro with an M5 chip", published: 1.day.ago })

      expect(source_a.entries).to all(be_original)
    end

    it "resolves a title match on a Duplicate to its Original" do
      fetch(source_a, guid: "a1", title: headline, link: "https://a.example.com/apple", published: 2.days.ago)
      fetch(source_b, guid: "b1", title: headline, link: "https://b.example.com/apple", published: 1.day.ago)
      fetch(source_c, guid: "c1", title: headline, link: "https://c.example.com/apple", published: 1.hour.ago)

      expect(entry(source_c, "c1").duplicate_of).to eq(entry(source_a, "a1"))
    end

    it "prefers a link match over a title match" do
      fetch(source_a, guid: "a1", title: headline, published: 2.days.ago)
      fetch(source_b, guid: "b1", title: "Something else entirely happened today", link: "https://news.example.com/story")
      fetch(source_c, guid: "c1", title: headline, link: "https://news.example.com/story")

      expect(entry(source_c, "c1").duplicate_of).to eq(entry(source_b, "b1"))
    end
  end

  describe "the Original a Duplicate points to" do
    it "is the first-seen Entry, and later matches point to it too" do
      fetch(source_a, guid: "a1", link: "https://news.example.com/story")
      fetch(source_b, guid: "b1", link: "https://news.example.com/story")
      fetch(source_c, guid: "c1", link: "https://news.example.com/story")

      original = entry(source_a, "a1")
      expect(entry(source_b, "b1").duplicate_of).to eq(original)
      expect(entry(source_c, "c1").duplicate_of).to eq(original)
    end

    it "is the Duplicate's Original when the new Entry matches a Duplicate's link" do
      fetch(source_a, guid: "a1", link: "https://news.example.com/original-url")
      original = entry(source_a, "a1")
      # A Duplicate whose link differs from its Original's (as when matched by title).
      source_b.entries.create!(identifier: "b1", link: "https://mirror.example.com/copy", duplicate_of: original,
        published_at: 1.hour.ago, first_seen_at: Time.current)

      fetch(source_c, guid: "c1", link: "https://mirror.example.com/copy")

      expect(entry(source_c, "c1").duplicate_of).to eq(original)
    end
  end

  describe "within one Source" do
    it "keeps two Entries with the same normalised link as Originals" do
      fetch(source_a, { guid: "a1", link: "https://news.example.com/story" },
        { guid: "a2", link: "http://www.news.example.com/story/" })

      expect(source_a.entries).to all(be_original)
    end

    it "doesn't attach an Entry to an Original from its own Source through another Source's Duplicate" do
      fetch(source_a, guid: "a1", link: "https://news.example.com/story")
      fetch(source_b, guid: "b1", link: "https://news.example.com/story")

      fetch(source_a, { guid: "a1", link: "https://news.example.com/story" },
        { guid: "a2", link: "https://news.example.com/story" })

      expect(entry(source_a, "a2")).to be_original
    end
  end

  describe "updating in place" do
    it "keeps a Duplicate a Duplicate when its Source changes the link" do
      fetch(source_a, guid: "a1", link: "https://news.example.com/story")
      fetch(source_b, guid: "b1", link: "https://news.example.com/story")

      fetch(source_b, guid: "b1", link: "https://news.example.com/a-different-story")

      expect(entry(source_b, "b1").duplicate_of).to eq(entry(source_a, "a1"))
    end

    it "keeps an Original an Original when its Source changes the link to match another Source" do
      fetch(source_a, guid: "a1", link: "https://news.example.com/story")
      fetch(source_b, guid: "b1", link: "https://news.example.com/something-else")

      fetch(source_b, guid: "b1", link: "https://news.example.com/story")

      expect(entry(source_b, "b1")).to be_original
    end
  end

  it "rejects pointing a Duplicate at another Duplicate or at an Entry from its own Source" do
    fetch(source_a, guid: "a1", link: "https://news.example.com/story")
    fetch(source_b, guid: "b1", link: "https://news.example.com/story")

    chained = source_c.entries.build(identifier: "c1", duplicate_of: entry(source_b, "b1"),
      published_at: 1.hour.ago, first_seen_at: Time.current)
    same_source = source_a.entries.build(identifier: "a2", duplicate_of: entry(source_a, "a1"),
      published_at: 1.hour.ago, first_seen_at: Time.current)

    expect(chained).not_to be_valid
    expect(same_source).not_to be_valid
  end
end
