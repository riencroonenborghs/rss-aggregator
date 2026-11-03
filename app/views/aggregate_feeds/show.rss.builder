xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.rss version: "2.0", "xmlns:dc" => "http://purl.org/dc/elements/1.1/" do
  xml.channel do
    xml.title "RSS Aggregator"
    xml.link request.base_url
    xml.description "Entries from all Sources, newest first."

    @entries.each do |entry|
      xml.item do
        xml.title entry.title
        xml.link entry.link
        xml.guid "urn:rss-aggregator:entry:#{entry.id}", isPermaLink: "false"
        xml.pubDate entry.published_at.rfc2822
        xml.tag! "dc:creator", entry.author if entry.author.present?
        xml.source entry.source.display_name, url: entry.source.url
        xml.description entry.content
      end
    end
  end
end
