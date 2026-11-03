# Turns one parsed item from a Source into a stored Entry, creating it or
# updating the existing one with the same identifier in place.
#
# After `perform`, `outcome` is one of:
#   :created      a new Entry was stored
#   :updated      an existing Entry changed
#   :unchanged    an existing Entry was seen again with no changes
#   :too_old      the item was published before the retention period and skipped
#   :unidentified the item has no guid, link or title and was skipped
# and `entry` is the stored Entry (nil when skipped).
class EntryIngestor
  include Service

  attr_reader :entry, :outcome

  def initialize(source, item)
    @source = source
    @item = item
  end

  def perform
    return skip(:unidentified) if identifier.nil?
    return skip(:too_old) if published_at && published_at < Entry::RETENTION_PERIOD.ago

    @entry = @source.entries.find_or_initialize_by(identifier: identifier)
    @entry.assign_attributes(
      title: @item.title,
      link: @item.url,
      author: @item.author,
      summary: @item.summary,
      content: @item.content
    )
    if @entry.new_record?
      @entry.first_seen_at = Time.current
      @entry.published_at = published_at || @entry.first_seen_at
    end

    @outcome = if @entry.new_record? then :created elsif @entry.changed? then :updated else :unchanged end
    changes = @entry.changed
    @entry.save!
    log_entry_saved(changes)
  end

  def created?
    outcome == :created
  end

  private

  def skip(outcome)
    @outcome = outcome
    log_warn "Skipped item without a guid, link or title", source_url: @source.url if outcome == :unidentified
  end

  def log_entry_saved(changes)
    case outcome
    when :created
      log_info "Stored new Entry", source_url: @source.url, entry_id: @entry.id, title: @entry.title
    when :updated
      log_info "Updated Entry", source_url: @source.url, entry_id: @entry.id, changed: changes
    end
  end

  # The item's own published date, ignoring dates in the future. Nil means the
  # Entry is treated as published when it was first seen.
  def published_at
    return @published_at if defined?(@published_at)

    published = @item.published
    @published_at = published if published && published <= Time.current
  end

  # Identity within the Source: the guid / Atom id, else the link, else a hash
  # of the title and published date.
  def identifier
    return @identifier if defined?(@identifier)

    @identifier = @item.entry_id.presence || @item.url.presence || title_and_date_hash
  end

  def title_and_date_hash
    return if @item.title.blank?

    "sha256:" + Digest::SHA256.hexdigest([ @item.title, @item.published&.utc&.iso8601 ].join("\n"))
  end
end
