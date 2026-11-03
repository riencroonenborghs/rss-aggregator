# Turns one parsed item from a Source into a stored Entry, creating it or
# updating the existing one with the same identifier. After `perform`, `entry`
# is the saved Entry, or nil when the item couldn't be identified.
class EntryIngestor
  include Service

  attr_reader :entry

  def initialize(source, item)
    @source = source
    @item = item
  end

  def perform
    if identifier.blank?
      log_warn "Skipped item without an identifier", source_url: @source.url, title: @item.title
      return
    end

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
      @entry.published_at = @item.published || @entry.first_seen_at
    end
    created = @entry.new_record?
    changes = @entry.changed
    @entry.save!
    log_entry_saved(created, changes)
  end

  # Whether this run stored a new Entry, rather than updating or skipping one.
  def created?
    entry.present? && entry.previously_new_record?
  end

  private

  def log_entry_saved(created, changes)
    if created
      log_info "Stored new Entry", source_url: @source.url, entry_id: @entry.id, title: @entry.title
    elsif changes.any?
      log_info "Updated Entry", source_url: @source.url, entry_id: @entry.id, changed: changes
    end
  end

  def identifier
    @item.entry_id
  end
end
