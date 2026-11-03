require "rails_helper"

RSpec.describe SourceFetcher do
  let(:source) { Source.create!(url: "https://blog.example.com/feed.xml", name: "Example Blog") }

  def serve(fixture, status: 200)
    stub_request(:get, source.url).to_return(status: status, body: file_fixture("feeds/#{fixture}").read)
  end

  # Serves an RSS 2.0 Source built from item hashes. Keys: title, link, guid,
  # pub_date (a Time), description, content.
  def serve_rss(*items)
    xml = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |x|
      x.rss(version: "2.0", "xmlns:content" => "http://purl.org/rss/1.0/modules/content/") do
        x.channel do
          x.title "Example Blog"
          x.link "https://blog.example.com/"
          x.description "An example Source"
          items.each do |item|
            x.item do
              x.title item[:title] if item[:title]
              x.link item[:link] if item[:link]
              x.guid item[:guid], isPermaLink: "false" if item[:guid]
              x.pubDate item[:pub_date].rfc2822 if item[:pub_date]
              x.description item[:description] if item[:description]
              x["content"].encoded item[:content] if item[:content]
            end
          end
        end
      end
    end.to_xml
    stub_request(:get, source.url).to_return(body: xml)
  end

  describe "RSS 2.0 Sources" do
    it "stores one Entry per item with its fields" do
      serve("rss2.xml")

      expect(source.fetch).to eq(2)

      entry = source.entries.find_by!(identifier: "example-2")
      expect(entry).to have_attributes(
        title: "Second post",
        link: "https://blog.example.com/second",
        author: "Jane Doe",
        published_at: Time.utc(2026, 11, 2, 9),
        summary: "Summary of the second post",
        content: "<p>The <strong>second</strong> post.</p>"
      )
      expect(entry.first_seen_at).to be_within(5.seconds).of(Time.current)
    end

    it "doesn't create repeats when the same Source is fetched twice" do
      serve("rss2.xml")

      source.fetch
      expect(source.fetch).to eq(0)
      expect(source.entries.count).to eq(2)
    end
  end

  describe "Atom Sources" do
    it "stores one Entry per entry with the same fields as RSS" do
      serve("atom.xml")

      expect(source.fetch).to eq(2)

      expect(source.entries.find_by!(identifier: "urn:uuid:entry-1")).to have_attributes(
        title: "Atom post",
        link: "https://atom.example.com/atom-post",
        author: "Alex Atom",
        published_at: Time.utc(2026, 11, 2, 9),
        summary: "Summary of the Atom post",
        content: "<p>The Atom post.</p>"
      )
    end

    it "uses the updated date when an entry has no published date" do
      serve("atom.xml")

      source.fetch

      expect(source.entries.find_by!(identifier: "urn:uuid:entry-2").published_at).to eq(Time.utc(2026, 11, 1, 9))
    end

    it "doesn't create repeats when fetched twice" do
      serve("atom.xml")

      source.fetch
      expect(source.fetch).to eq(0)
    end
  end

  describe "identity" do
    let(:pub_date) { 1.day.ago.change(usec: 0) }

    it "prefers the guid" do
      serve_rss({ guid: "guid-1", link: "https://blog.example.com/a", title: "A", pub_date: pub_date })

      source.fetch

      expect(source.entries.pluck(:identifier)).to eq([ "guid-1" ])
    end

    it "falls back to the link when there is no guid" do
      serve_rss({ link: "https://blog.example.com/a", title: "A", pub_date: pub_date })

      source.fetch

      expect(source.entries.pluck(:identifier)).to eq([ "https://blog.example.com/a" ])
    end

    it "falls back to a hash of title and date when there is no guid or link" do
      serve_rss({ title: "A", pub_date: pub_date }, { title: "B", pub_date: pub_date })

      source.fetch

      expect(source.entries.pluck(:identifier)).to all(start_with("sha256:"))
      expect(source.entries.pluck(:identifier).uniq.size).to eq(2)
    end

    it "doesn't create repeats for guid-less items when fetched twice" do
      serve_rss({ link: "https://blog.example.com/a", title: "A", pub_date: pub_date },
        { title: "B", pub_date: pub_date })

      source.fetch
      expect(source.fetch).to eq(0)
      expect(source.entries.count).to eq(2)
    end

    it "skips an item with no guid, link or title" do
      serve_rss({ description: "Nothing to identify me by", pub_date: pub_date })

      expect(source.fetch).to eq(0)
      expect(source.entries).to be_empty
    end
  end

  describe "changed items" do
    let(:pub_date) { 2.days.ago.change(usec: 0) }

    it "updates the Entry in place and keeps its published date and first-seen time" do
      serve_rss({ guid: "g", title: "Original title", content: "<p>v1</p>", pub_date: pub_date })
      source.fetch
      entry = source.entries.sole
      first_seen_at = entry.first_seen_at

      travel 1.hour do
        serve_rss({ guid: "g", title: "Corrected title", content: "<p>v2</p>", pub_date: 1.minute.ago })
        expect(source.fetch).to eq(0)
      end

      expect(entry.reload).to have_attributes(
        title: "Corrected title",
        content: "<p>v2</p>",
        published_at: pub_date,
        first_seen_at: first_seen_at
      )
      expect(source.entries.count).to eq(1)
    end
  end

  describe "published dates" do
    it "uses the first-seen time when an item has no published date" do
      serve_rss({ guid: "undated", title: "Undated" })

      source.fetch

      entry = source.entries.sole
      expect(entry.published_at).to eq(entry.first_seen_at)
    end

    it "uses the first-seen time when an item is dated in the future" do
      serve_rss({ guid: "future", title: "From the future", pub_date: 3.days.from_now })

      source.fetch

      entry = source.entries.sole
      expect(entry.published_at).to eq(entry.first_seen_at)
    end

    it "skips items published more than 30 days ago" do
      serve_rss({ guid: "old", title: "Old", pub_date: 31.days.ago },
        { guid: "recent", title: "Recent", pub_date: 29.days.ago })

      expect(source.fetch).to eq(1)
      expect(source.entries.pluck(:identifier)).to eq([ "recent" ])
    end
  end

  describe "failures" do
    it "raises a fetch error when the Source responds with an HTTP error" do
      stub_request(:get, source.url).to_return(status: 500)

      expect { source.fetch }.to raise_error(SourceFetcher::Error, /HTTP 500/)
    end

    it "raises a fetch error when the Source isn't a feed" do
      stub_request(:get, source.url).to_return(body: "<html><body>Not a feed</body></html>")

      expect { source.fetch }.to raise_error(SourceFetcher::Error, /not an RSS or Atom feed/)
    end
  end
end
