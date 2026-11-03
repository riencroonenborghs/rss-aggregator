# Fetches one Source end to end: downloads it politely (conditional GET with a
# User-Agent), parses it and hands each item to the EntryIngestor.
#
# A failed fetch never raises: the error is recorded on the Source, its
# existing Entries are left alone, and the next fetch tries again. After
# `perform`, `success?` tells whether the fetch worked, `error` holds the
# message when it didn't, and `new_entries_count` how many Entries were added.
class SourceFetcher
  include Service

  class Error < StandardError; end

  NETWORK_ERRORS = [
    HTTParty::Error, SocketError, Timeout::Error, SystemCallError, OpenSSL::SSL::SSLError, IOError
  ].freeze

  attr_reader :new_entries_count, :error

  def initialize(source)
    @source = source
    @new_entries_count = 0
  end

  def perform
    log_info "Fetching Source", url: @source.url
    response = download

    if response.code == 304
      record_success
      log_info "Source not modified", url: @source.url
      return
    end

    raise Error, "HTTP #{response.code}" unless response.success?

    feed = parse(response.body)
    ingest(feed)
    record_success(feed: feed, response: response)
  rescue Error, *NETWORK_ERRORS => e
    record_failure(e)
  end

  def success?
    error.nil?
  end

  private

  def download
    response = HTTParty.get(@source.url, headers: request_headers, timeout: settings.timeout)
    log_info "Downloaded Source", url: @source.url, status: response.code, bytes: response.body.to_s.bytesize
    response
  end

  def request_headers
    {
      "User-Agent" => settings.user_agent,
      "If-None-Match" => @source.etag,
      "If-Modified-Since" => @source.last_modified
    }.compact
  end

  def parse(body)
    Feedjira.parse(body)
  rescue Feedjira::NoParserAvailable
    raise Error, "not an RSS or Atom feed"
  end

  def ingest(feed)
    outcomes = feed.entries.map { |item| EntryIngestor.perform(@source, item).outcome }.tally
    @new_entries_count = outcomes.fetch(:created, 0)
    log_info "Fetched Source", url: @source.url, items: feed.entries.size, **outcomes
  end

  def record_success(feed: nil, response: nil)
    attributes = { last_fetched_at: Time.current, last_error: nil, last_error_at: nil }
    if response
      attributes[:etag] = response.headers["etag"]
      attributes[:last_modified] = response.headers["last-modified"]
    end
    attributes[:name] = feed.title.strip if feed && @source.name.blank? && feed.title.present?
    @source.update!(attributes)
  end

  def record_failure(exception)
    @error = "#{exception.class.name}: #{exception.message}"
    @source.update!(last_error: @error, last_error_at: Time.current)
    log_error "Failed to fetch Source", exception, url: @source.url
  end

  def settings
    Rails.configuration.x.source_fetcher
  end
end
