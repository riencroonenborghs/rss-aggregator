# frozen_string_literal: true

# Removes a Source and all its Entries without losing stories that other
# Sources also carry. For each of the Source's Originals that has Duplicates,
# the earliest-seen Duplicate becomes the new Original and the remaining
# Duplicates are re-pointed to it. A remaining Duplicate from the same Source
# as the promoted one becomes an Original as well, because Entries within one
# Source are never Duplicates of each other.
#
# After `perform`, `deleted_entries_count` and `promoted_count` say what
# happened.
class SourceRemover
  include Service

  attr_reader :deleted_entries_count, :promoted_count

  def initialize(source)
    @source = source
    @promoted_count = 0
  end

  def perform
    Source.transaction do
      originals_with_duplicates.find_each { |original| promote_earliest_duplicate_of(original) }
      @deleted_entries_count = @source.entries.count
      @source.destroy!
    end

    log_info "Removed Source", url: @source.url, deleted_entries: @deleted_entries_count, promoted: @promoted_count
  end

  private

  def originals_with_duplicates
    @source.entries.originals.where(id: Entry.select(:duplicate_of_id))
  end

  def promote_earliest_duplicate_of(original)
    promoted, *others = original.duplicates.order(:first_seen_at, :id).to_a
    same_source, other_sources = others.partition { |duplicate| duplicate.source_id == promoted.source_id }

    promoted.update_columns(duplicate_of_id: nil)
    Entry.where(id: other_sources.map(&:id)).update_all(duplicate_of_id: promoted.id)
    Entry.where(id: same_source.map(&:id)).update_all(duplicate_of_id: nil)
    @promoted_count += 1 + same_source.size

    log_info "Promoted Duplicate to Original", removed_original_id: original.id, promoted_id: promoted.id
  end
end
