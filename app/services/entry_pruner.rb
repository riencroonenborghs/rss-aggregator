# frozen_string_literal: true

# Keeps the database to a rolling window: deletes every Entry published more
# than Entry::RETENTION_PERIOD ago. An expired Original takes its Duplicates
# with it, even newer ones, so a story can't resurface through a late
# Duplicate. After `perform`, `deleted_count` is how many Entries went.
class EntryPruner
  include Service

  attr_reader :deleted_count

  def initialize(now: Time.current)
    @cutoff = now - Entry::RETENTION_PERIOD
  end

  def perform
    expired = Entry.where(published_at: ...@cutoff)

    Entry.transaction do
      # Duplicates go first: they reference their Original.
      duplicates = Entry.where(duplicate_of_id: expired.select(:id)).delete_all
      @deleted_count = duplicates + expired.delete_all
    end

    log_info "Pruned expired Entries", cutoff: @cutoff, deleted: @deleted_count
  end
end
