# Fetches one Source end to end: downloads it, parses it and hands each item
# to the EntryIngestor. After `perform`, `new_entries_count` holds how many
# new Entries were stored.
class SourceFetcher
  include Service

  class Error < StandardError; end

  attr_reader :new_entries_count

  def initialize(source)
    @source = source
    @new_entries_count = 0
  end

  def perform
    log_info "Fetching Source", url: @source.url
    items = parse(download).entries
    @new_entries_count = items.count { |item| EntryIngestor.perform(@source, item).created? }
    log_info "Fetched Source", url: @source.url, items: items.size, new_entries: @new_entries_count
  rescue Error => e
    log_error "Failed to fetch Source", e, url: @source.url
    raise
  end

  private

  def download
    response = HTTParty.get(@source.url)
    log_info "Downloaded Source", url: @source.url, status: response.code, bytes: response.body.to_s.bytesize
    raise Error, "HTTP #{response.code} from #{@source.url}" unless response.success?

    response.body
  end

  def parse(body)
    Feedjira.parse(body)
  rescue Feedjira::NoParserAvailable
    raise Error, "#{@source.url} is not an RSS or Atom feed"
  end
end
