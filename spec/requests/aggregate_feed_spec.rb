require "rails_helper"

RSpec.describe "Aggregate Feed", type: :request do
  let(:source) { Source.create!(url: "https://blog.example.com/feed.xml", name: "Example Blog") }

  def create_entry(identifier, published_at:, **attributes)
    source.entries.create!(identifier: identifier, published_at: published_at, first_seen_at: Time.current, **attributes)
  end

  def items
    Nokogiri::XML(response.body).xpath("/rss/channel/item")
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

  it "omits the author when the Entry has none" do
    create_entry("anonymous", published_at: 1.day.ago, title: "Anonymous")

    get "/feed.rss"

    expect(items.first.at_xpath("dc:creator", "dc" => "http://purl.org/dc/elements/1.1/")).to be_nil
  end
end
