# frozen_string_literal: true

require "did_you_mean"

# Finds the Original that a new Entry duplicates, if any, following the rules
# in docs/adr/0001-cross-source-duplicate-detection.md. After `perform`,
# `original` is that Original, or nil when the Entry is itself an Original.
#
# Two Entries from different Sources are the same story when either:
#   - link:  their normalised links are equal, or
#   - title: their normalised titles are at least TITLE_SIMILARITY alike by
#            Levenshtein distance relative to length, both have at least
#            TITLE_MIN_WORDS words, and they were published within
#            TITLE_WINDOW of each other.
#
# A match that is itself a Duplicate resolves to its Original, so Duplicates
# never form chains, and an Original from the Entry's own Source never counts:
# within a Source, the publisher's guid is the only identity. When several
# Entries match, the first-seen one wins.
class DuplicateDetector
  include Service

  TITLE_SIMILARITY = 0.9
  TITLE_MIN_WORDS = 4
  TITLE_WINDOW = 3.days

  attr_reader :original

  def initialize(entry)
    @entry = entry
  end

  def perform
    @original = match_by_link || match_by_title
  end

  private

  def match_by_link
    return if @entry.normalised_link.blank?

    first_original_among(other_sources_entries.where(normalised_link: @entry.normalised_link))
  end

  def match_by_title
    title = @entry.normalised_title
    return unless comparable_title?(title)

    window = (@entry.published_at - TITLE_WINDOW)..(@entry.published_at + TITLE_WINDOW)
    candidates = other_sources_entries.where(published_at: window).where.not(normalised_title: nil)

    first_original_among(candidates.lazy.select { |candidate| similar_titles?(title, candidate.normalised_title) })
  end

  def other_sources_entries
    Entry.includes(:duplicate_of).where.not(source_id: @entry.source_id).order(:first_seen_at, :id)
  end

  def first_original_among(matches)
    matches.lazy.map { |match| match.duplicate_of || match }
      .find { |original| original.source_id != @entry.source_id }
  end

  def comparable_title?(title)
    title.present? && title.split.size >= TITLE_MIN_WORDS
  end

  def similar_titles?(title, other)
    return false unless comparable_title?(other)

    longest = [ title.length, other.length ].max
    # The distance is at least the difference in length, so skip pairs that
    # can't reach the threshold before doing the full comparison.
    return false if (title.length - other.length).abs > longest * (1 - TITLE_SIMILARITY)

    1 - DidYouMean::Levenshtein.distance(title, other).fdiv(longest) >= TITLE_SIMILARITY
  end
end
