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

      expect(source.fetch.new_entries_count).to eq(2)

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
      expect(source.fetch.new_entries_count).to eq(0)
      expect(source.entries.count).to eq(2)
    end
  end

  describe "Atom Sources" do
    it "stores one Entry per entry with the same fields as RSS" do
      serve("atom.xml")

      expect(source.fetch.new_entries_count).to eq(2)

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
      expect(source.fetch.new_entries_count).to eq(0)
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
      expect(source.fetch.new_entries_count).to eq(0)
      expect(source.entries.count).to eq(2)
    end

    it "skips an item with no guid, link or title" do
      serve_rss({ description: "Nothing to identify me by", pub_date: pub_date })

      expect(source.fetch.new_entries_count).to eq(0)
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
        expect(source.fetch.new_entries_count).to eq(0)
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

      expect(source.fetch.new_entries_count).to eq(1)
      expect(source.entries.pluck(:identifier)).to eq([ "recent" ])
    end
  end

  describe "polite fetching" do
    it "identifies itself with the configured User-Agent" do
      serve("rss2.xml")

      source.fetch

      expect(a_request(:get, source.url).with(headers: { "User-Agent" => "RSSAggregator/1.0" })).to have_been_made
    end

    it "stores the ETag and Last-Modified from the response" do
      stub_request(:get, source.url).to_return(body: file_fixture("feeds/rss2.xml").read,
        headers: { "ETag" => '"v1"', "Last-Modified" => "Mon, 02 Nov 2026 09:00:00 GMT" })

      source.fetch

      expect(source.reload).to have_attributes(etag: '"v1"', last_modified: "Mon, 02 Nov 2026 09:00:00 GMT")
    end

    it "sends the stored ETag and Last-Modified back on the next fetch" do
      source.update!(etag: '"v1"', last_modified: "Mon, 02 Nov 2026 09:00:00 GMT")
      serve("rss2.xml")

      source.fetch

      expect(a_request(:get, source.url).with(headers: {
        "If-None-Match" => '"v1"', "If-Modified-Since" => "Mon, 02 Nov 2026 09:00:00 GMT"
      })).to have_been_made
    end

    it "sends no conditional headers when nothing is stored" do
      serve("rss2.xml")

      source.fetch

      expect(a_request(:get, source.url).with { |request|
        !request.headers.key?("If-None-Match") && !request.headers.key?("If-Modified-Since")
      }).to have_been_made
    end

    it "treats 304 Not Modified as a successful fetch that changes no Entries" do
      serve("rss2.xml")
      source.fetch
      entries_before = source.entries.order(:id).map(&:attributes)
      source.update!(etag: '"v1"')

      travel 30.minutes do
        stub_request(:get, source.url).to_return(status: 304)
        fetch = source.fetch

        expect(fetch).to be_success
        expect(fetch.new_entries_count).to eq(0)
        expect(source.reload.last_fetched_at).to be_within(1.second).of(Time.current)
      end
      expect(source.entries.order(:id).map(&:attributes)).to eq(entries_before)
      expect(source.reload.etag).to eq('"v1"')
    end
  end

  describe "Source health" do
    it "records when the Source was last fetched successfully" do
      serve("rss2.xml")

      expect(source.fetch).to be_success

      expect(source.reload.last_fetched_at).to be_within(5.seconds).of(Time.current)
      expect(source.last_error).to be_nil
    end

    {
      "the Source responds with an HTTP error" => -> { stub_request(:get, source.url).to_return(status: 500) },
      "the Source responds with Not Found" => -> { stub_request(:get, source.url).to_return(status: 404) },
      "the request times out" => -> { stub_request(:get, source.url).to_timeout },
      "the connection is refused" => -> { stub_request(:get, source.url).to_raise(Errno::ECONNREFUSED) },
      "the Source isn't a feed" => -> { stub_request(:get, source.url).to_return(body: "<html><body>Not a feed</body></html>") },
      "the body isn't XML at all" => -> { stub_request(:get, source.url).to_return(body: "{ not xml") }
    }.each do |failure, stub|
      it "records the error without raising and keeps existing Entries when #{failure}" do
        serve("rss2.xml")
        source.fetch
        instance_exec(&stub)

        fetch = nil
        expect { fetch = source.fetch }.not_to raise_error

        expect(fetch).not_to be_success
        expect(fetch.error).to be_present
        expect(source.reload.last_error).to eq(fetch.error)
        expect(source.last_error_at).to be_within(5.seconds).of(Time.current)
        expect(source.entries.count).to eq(2)
      end
    end

    it "clears the recorded error on the next successful fetch" do
      stub_request(:get, source.url).to_return(status: 500).then
        .to_return(body: file_fixture("feeds/rss2.xml").read)
      source.fetch
      expect(source.reload.last_error).to include("HTTP 500")

      source.fetch

      expect(source.reload).to have_attributes(last_error: nil, last_error_at: nil)
    end

    it "keeps the previous successful fetch time when a fetch fails" do
      serve("rss2.xml")
      source.fetch
      last_fetched_at = source.reload.last_fetched_at

      travel 30.minutes do
        stub_request(:get, source.url).to_return(status: 500)
        source.fetch
      end

      expect(source.reload.last_fetched_at).to eq(last_fetched_at)
    end
  end

  describe "naming" do
    it "takes the Source's own title when the Source has no name" do
      source.update!(name: nil)
      serve("rss2.xml")

      source.fetch

      expect(source.reload.name).to eq("Example Blog")
    end

    it "keeps a name the operator gave" do
      source.update!(name: "My name for it")
      serve("atom.xml")

      source.fetch

      expect(source.reload.name).to eq("My name for it")
    end
  end
end
