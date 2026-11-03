require "rails_helper"

RSpec.describe SourceFetcher do
  let(:source) { Source.create!(url: "https://blog.example.com/feed.xml", name: "Example Blog") }

  def serve(fixture, status: 200)
    stub_request(:get, source.url).to_return(status: status, body: file_fixture("feeds/#{fixture}").read)
  end

  it "stores one Entry per RSS 2.0 item with its fields" do
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

  it "raises a fetch error when the Source responds with an HTTP error" do
    stub_request(:get, source.url).to_return(status: 500)

    expect { source.fetch }.to raise_error(SourceFetcher::Error, /HTTP 500/)
  end

  it "raises a fetch error when the Source isn't a feed" do
    stub_request(:get, source.url).to_return(body: "<html><body>Not a feed</body></html>")

    expect { source.fetch }.to raise_error(SourceFetcher::Error, /not an RSS or Atom feed/)
  end
end
