# Finds the Original that a new Entry duplicates, if any, following the rules
# in docs/adr/0001-cross-source-duplicate-detection.md. After `perform`,
# `original` is that Original, or nil when the Entry is itself an Original.
#
# Rules implemented so far:
#   - link: an Entry from a different Source with the same normalised link.
#
# A match that is itself a Duplicate resolves to its Original, so Duplicates
# never form chains, and an Original from the Entry's own Source never counts:
# within a Source, the publisher's guid is the only identity.
class DuplicateDetector
  include Service

  attr_reader :original

  def initialize(entry)
    @entry = entry
  end

  def perform
    @original = match_by_link
  end

  private

  def match_by_link
    return if @entry.normalised_link.blank?

    candidates = Entry.includes(:duplicate_of)
      .where(normalised_link: @entry.normalised_link)
      .where.not(source_id: @entry.source_id)
      .order(:first_seen_at, :id)

    candidates.lazy.map { |candidate| candidate.duplicate_of || candidate }
      .find { |original| original.source_id != @entry.source_id }
  end
end
