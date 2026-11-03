# Serves the Aggregate Feed. Inherits from ActionController::Base rather than
# ApplicationController so the modern-browser gate never blocks feed readers.
class AggregateFeedsController < ActionController::Base
  PAGE_SIZE = 100

  DEFAULT_TITLE = "RSS Aggregator".freeze
  DEFAULT_DESCRIPTION = "Entries from all Sources, newest first.".freeze

  helper_method :channel, :page_url

  def show
    @page = [ params[:page].to_i, 1 ].max

    # Load one Entry past the page to learn whether a next page exists
    # without a separate count query.
    entries = Entry.originals.includes(:source).newest_first.offset((@page - 1) * PAGE_SIZE).limit(PAGE_SIZE + 1).to_a
    @entries = entries.first(PAGE_SIZE)
    @next_page = @page + 1 if entries.size > PAGE_SIZE
    @previous_page = @page - 1 if @page > 1
  end

  private

  # Channel metadata from config.x.aggregate_feed, falling back to defaults.
  def channel
    @channel ||= begin
      config = Rails.configuration.x.aggregate_feed
      {
        title: config.title.presence || DEFAULT_TITLE,
        link: config.link.presence || request.base_url,
        description: config.description.presence || DEFAULT_DESCRIPTION
      }
    end
  end

  # Page 1 lives at /feed.rss; later pages at /feed.rss?page=N.
  def page_url(page)
    aggregate_feed_url(format: :rss, page: (page if page > 1))
  end
end
