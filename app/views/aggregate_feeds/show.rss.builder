xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.rss version: "2.0", "xmlns:dc" => "http://purl.org/dc/elements/1.1/", "xmlns:atom" => "http://www.w3.org/2005/Atom" do
  xml.channel do
    xml.title channel[:title]
    xml.link channel[:link]
    xml.description channel[:description]

    # Paging links (RFC 5005) so readers that support them can walk the history.
    xml.tag! "atom:link", rel: "self", type: "application/rss+xml", href: page_url(@page)
    xml.tag! "atom:link", rel: "next", type: "application/rss+xml", href: page_url(@next_page) if @next_page
    xml.tag! "atom:link", rel: "previous", type: "application/rss+xml", href: page_url(@previous_page) if @previous_page

    @entries.each do |entry|
      xml.item do
        xml.title entry.title
        xml.link entry.link
        xml.guid "urn:rss-aggregator:entry:#{entry.id}", isPermaLink: "false"
        xml.pubDate entry.published_at.rfc2822
        xml.tag! "dc:creator", entry.author if entry.author.present?
        xml.source entry.source.display_name, url: entry.source.url
        xml.description entry.content.presence || entry.summary
      end
    end
  end
end
