require "rails_helper"

RSpec.describe "Aggregate Feed", type: :request do
  let(:source) { Source.create!(url: "https://blog.example.com/feed.xml", name: "Example Blog") }

  def create_entry(identifier, published_at:, **attributes)
    source.entries.create!(identifier: identifier, published_at: published_at, first_seen_at: Time.current, **attributes)
  end

  ATOM = { "atom" => "http://www.w3.org/2005/Atom" }.freeze

  def items
    Nokogiri::XML(response.body).xpath("/rss/channel/item")
  end

  def paging_link(rel)
    Nokogiri::XML(response.body).at_xpath("/rss/channel/atom:link[@rel='#{rel}']", ATOM)&.[]("href")
  end

  # Inserts `count` Entries, numbered so that "Entry 1" is the newest.
  def insert_entries(count)
    now = Time.current
    Entry.insert_all!(Array.new(count) do |i|
      { source_id: source.id, identifier: "e#{i + 1}", title: "Entry #{i + 1}", published_at: now - (i + 1).minutes,
        first_seen_at: now, created_at: now, updated_at: now }
    end)
  end

  def with_aggregate_feed_config(**values)
    config = Rails.configuration.x.aggregate_feed
    previous = values.keys.index_with { |key| config[key] }
    values.each { |key, value| config[key] = value }
    yield
  ensure
    previous.each { |key, value| config[key] = value }
  end

  it "serves well-formed RSS 2.0 without authentication" do
    get "/feed.rss"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/rss+xml")
    doc = Nokogiri::XML(response.body) { |config| config.strict }
    expect(doc.root.name).to eq("rss")
    expect(doc.root["version"]).to eq("2.0")
    expect(doc.at_xpath("/rss/channel/title").text).to be_present
  end

  it "lists Entries newest first by published date" do
    create_entry("old", title: "Old", published_at: 2.days.ago)
    create_entry("new", title: "New", published_at: 1.hour.ago)
    create_entry("mid", title: "Mid", published_at: 1.day.ago)

    get "/feed.rss"

    expect(items.map { |item| item.at_xpath("title").text }).to eq(%w[New Mid Old])
  end

  it "carries the original title and link, pubDate, author, Source and content for each item" do
    published_at = Time.utc(2026, 11, 2, 9)
    create_entry("example-2", published_at: published_at, title: "Second post", link: "https://blog.example.com/second",
      author: "Jane Doe", content: "<p>The <strong>second</strong> post.</p>")

    get "/feed.rss"

    item = items.first
    expect(item.at_xpath("title").text).to eq("Second post")
    expect(item.at_xpath("link").text).to eq("https://blog.example.com/second")
    expect(Time.rfc2822(item.at_xpath("pubDate").text)).to eq(published_at)
    expect(item.at_xpath("dc:creator", "dc" => "http://purl.org/dc/elements/1.1/").text).to eq("Jane Doe")
    expect(item.at_xpath("source").text).to eq("Example Blog")
    expect(item.at_xpath("source")["url"]).to eq("https://blog.example.com/feed.xml")
    expect(item.at_xpath("description").text).to eq("<p>The <strong>second</strong> post.</p>")
  end

  it "gives each item a guid that is not a permalink and stays the same across requests" do
    create_entry("example-1", published_at: 1.day.ago, title: "First")

    get "/feed.rss"
    first_guid = items.first.at_xpath("guid")
    get "/feed.rss"

    expect(first_guid["isPermaLink"]).to eq("false")
    expect(items.first.at_xpath("guid").text).to eq(first_guid.text)
  end

  it "keeps an Entry in its position after the Source updates it" do
    rss = lambda do |older_title, older_date|
      <<~XML
        <rss version="2.0"><channel><title>Example Blog</title><link>https://blog.example.com/</link><description>x</description>
          <item><guid>newer</guid><title>Newer</title><pubDate>#{1.hour.ago.rfc2822}</pubDate></item>
          <item><guid>older</guid><title>#{older_title}</title><pubDate>#{older_date.rfc2822}</pubDate></item>
        </channel></rss>
      XML
    end
    stub_request(:get, source.url).to_return(body: rss.call("Older", 1.day.ago))
    source.fetch
    stub_request(:get, source.url).to_return(body: rss.call("Older, corrected", 1.minute.ago))
    source.fetch

    get "/feed.rss"

    expect(items.map { |item| item.at_xpath("title").text }).to eq([ "Newer", "Older, corrected" ])
  end

  it "omits the author when the Entry has none" do
    create_entry("anonymous", published_at: 1.day.ago, title: "Anonymous")

    get "/feed.rss"

    expect(items.first.at_xpath("dc:creator", "dc" => "http://purl.org/dc/elements/1.1/")).to be_nil
  end

  it "lists only Originals, never their Duplicates" do
    other_source = Source.create!(url: "https://other.example.com/feed.xml", name: "Other")
    original = create_entry("original", title: "Original", published_at: 2.hours.ago, link: "https://news.example.com/story")
    other_source.entries.create!(identifier: "duplicate", title: "Duplicate", link: "http://news.example.com/story/",
      published_at: 1.hour.ago, first_seen_at: Time.current, duplicate_of: original)

    get "/feed.rss"

    expect(items.map { |item| item.at_xpath("title").text }).to eq([ "Original" ])
  end

  it "doesn't count Duplicates towards a page" do
    other_source = Source.create!(url: "https://other.example.com/feed.xml", name: "Other")
    insert_entries(100)
    other_source.entries.create!(identifier: "duplicate", title: "Duplicate", published_at: 1.second.ago,
      first_seen_at: Time.current, duplicate_of: source.entries.first)

    get "/feed.rss"

    expect(items.size).to eq(100)
    expect(paging_link("next")).to be_nil
  end

  describe "pagination" do
    before { insert_entries(250) }

    def titles = items.map { |item| item.at_xpath("title").text }

    it "serves the 100 newest Entries on page 1" do
      get "/feed.rss"

      expect(titles).to eq((1..100).map { |n| "Entry #{n}" })
    end

    it "serves later pages with ?page=N" do
      get "/feed.rss", params: { page: 3 }

      expect(titles).to eq((201..250).map { |n| "Entry #{n}" })
    end

    it "serves a valid, empty channel past the last page" do
      get "/feed.rss", params: { page: 4 }

      expect(response).to have_http_status(:ok)
      expect { Nokogiri::XML(response.body) { |config| config.strict } }.not_to raise_error
      expect(Nokogiri::XML(response.body).at_xpath("/rss/channel/title")).to be_present
      expect(items).to be_empty
    end

    it "treats a missing, zero, negative or non-numeric page as page 1" do
      [ nil, "0", "-2", "abc" ].each do |page|
        get "/feed.rss", params: { page: page }.compact

        expect(titles.first).to eq("Entry 1")
      end
    end

    it "links page 1 to itself and the next page, with no previous page" do
      get "/feed.rss"

      expect(paging_link("self")).to eq("http://www.example.com/feed.rss")
      expect(paging_link("next")).to eq("http://www.example.com/feed.rss?page=2")
      expect(paging_link("previous")).to be_nil
    end

    it "links a middle page to both neighbours" do
      get "/feed.rss", params: { page: 2 }

      expect(paging_link("self")).to eq("http://www.example.com/feed.rss?page=2")
      expect(paging_link("next")).to eq("http://www.example.com/feed.rss?page=3")
      expect(paging_link("previous")).to eq("http://www.example.com/feed.rss")
    end

    it "links the last page back but not forward" do
      get "/feed.rss", params: { page: 3 }

      expect(paging_link("next")).to be_nil
      expect(paging_link("previous")).to eq("http://www.example.com/feed.rss?page=2")
    end
  end

  it "has no next page when the Entries fit exactly on one page" do
    insert_entries(100)

    get "/feed.rss"

    expect(items.size).to eq(100)
    expect(paging_link("next")).to be_nil
  end

  describe "channel metadata" do
    def channel_field(name) = Nokogiri::XML(response.body).at_xpath("/rss/channel/#{name}").text

    it "comes from config" do
      with_aggregate_feed_config(title: "My Reading List", link: "https://reading.example.com",
        description: "Everything I follow") do
        get "/feed.rss"
      end

      expect(channel_field("title")).to eq("My Reading List")
      expect(channel_field("link")).to eq("https://reading.example.com")
      expect(channel_field("description")).to eq("Everything I follow")
    end

    it "falls back to defaults when the config is unset" do
      with_aggregate_feed_config(title: nil, link: nil, description: nil) do
        get "/feed.rss"
      end

      expect(channel_field("title")).to eq("RSS Aggregator")
      expect(channel_field("link")).to eq("http://www.example.com")
      expect(channel_field("description")).to eq("Entries from all Sources, newest first.")
    end
  end

  describe "item description" do
    def description = items.first.at_xpath("description").text

    it "uses the summary when the Entry has no content" do
      create_entry("summary-only", published_at: 1.hour.ago, summary: "<p>Just a <em>summary</em></p>")

      get "/feed.rss"

      expect(description).to eq("<p>Just a <em>summary</em></p>")
    end

    it "prefers the content over the summary" do
      create_entry("both", published_at: 1.hour.ago, summary: "Short", content: "<p>Full</p>")

      get "/feed.rss"

      expect(description).to eq("<p>Full</p>")
    end

    it "escapes the HTML so it survives as text, not as XML elements" do
      create_entry("html", published_at: 1.hour.ago, content: %(<p class="x">A &amp; B <img src="a.png"></p>))

      get "/feed.rss"

      expect(response.body).to include("&lt;p class=\"x\"&gt;A &amp;amp; B &lt;img src=\"a.png\"&gt;&lt;/p&gt;")
      expect(description).to eq(%(<p class="x">A &amp; B <img src="a.png"></p>))
    end
  end
end
