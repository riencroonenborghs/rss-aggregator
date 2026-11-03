# frozen_string_literal: true

# == Schema Information
#
# Table name: entries
# Database name: primary
#
#  id               :integer          not null, primary key
#  author           :string
#  content          :text
#  first_seen_at    :datetime         not null
#  identifier       :string           not null
#  link             :string
#  normalised_link  :string
#  normalised_title :string
#  plain_text       :text
#  published_at     :datetime         not null
#  summary          :text
#  title            :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  duplicate_of_id  :integer
#  source_id        :integer          not null
#
# Indexes
#
#  index_entries_on_duplicate_of_id           (duplicate_of_id)
#  index_entries_on_normalised_link           (normalised_link)
#  index_entries_on_published_at              (published_at)
#  index_entries_on_source_id                 (source_id)
#  index_entries_on_source_id_and_identifier  (source_id,identifier) UNIQUE
#
# Foreign Keys
#
#  duplicate_of_id  (duplicate_of_id => entries.id)
#  source_id        (source_id => sources.id)
#
# A single piece of content pulled from a Source and stored by the aggregator.
#
# An Entry is either an Original or a Duplicate: a Duplicate is the same story
# as an Original seen earlier from a different Source, and points to it
# through `duplicate_of`. Only Originals appear in the Aggregate Feed. See
# docs/adr/0001-cross-source-duplicate-detection.md.
class Entry < ApplicationRecord
  RETENTION_PERIOD = 30.days

  belongs_to :source
  belongs_to :duplicate_of, class_name: "Entry", optional: true, inverse_of: :duplicates
  has_many :duplicates, class_name: "Entry", foreign_key: :duplicate_of_id, inverse_of: :duplicate_of

  scope :newest_first, -> { order(published_at: :desc, id: :desc) }
  scope :originals, -> { where(duplicate_of_id: nil) }

  validate :duplicate_of_is_an_original_from_another_source

  # Normalises a link so the same page matches across Sources: the host is
  # lowercased; the scheme, a leading "www.", default ports, a trailing slash,
  # utm_* query parameters and the fragment are ignored.
  def self.normalise_link(link)
    return if link.blank?

    uri = URI.parse(link.strip)
    return link.strip.downcase unless uri.host

    host = uri.host.downcase.delete_prefix("www.")
    port = ":#{uri.port}" if uri.port && uri.port != uri.default_port
    path = uri.path.to_s.chomp("/")
    query = uri.query.to_s.split("&").reject { |param| param.downcase.start_with?("utm_") }.join("&")

    "#{host}#{port}#{path}#{"?#{query}" if query.present?}"
  rescue URI::InvalidURIError
    link.strip.downcase
  end

  # Normalises a title for fuzzy comparison across Sources: lowercased, with
  # punctuation turned into spaces and runs of whitespace collapsed.
  def self.normalise_title(title)
    return if title.blank?

    title.downcase.gsub(/[[:punct:][:space:]]+/, " ").strip.presence
  end

  # The text of an HTML fragment as a reader sees it: tags dropped, entities
  # decoded and whitespace collapsed. Text nodes are joined with spaces so
  # words in adjacent elements ("<p>a</p><p>b</p>") don't run together.
  def self.plain_text_of(html)
    return if html.blank?

    Nokogiri::HTML5.fragment(html).xpath(".//text()").map(&:text).join(" ").squish.presence
  end

  # Originals and Duplicates whose title or plain text contains any of the
  # given words or phrases, as whole words, ignoring case and accents. Each
  # Keyword is quoted, so FTS5 query syntax in it is matched as plain text.
  # See docs/adr/0002-keyword-matching-with-sqlite-fts5.md.
  def self.matching(keywords)
    query = keywords.map { |keyword| %("#{keyword.gsub('"', '""')}") }.join(" OR ")

    where(id: select(:rowid).from("entries_fts").where("entries_fts MATCH ?", query))
  end

  def link=(value)
    super
    self.normalised_link = self.class.normalise_link(value)
  end

  def title=(value)
    super
    self.normalised_title = self.class.normalise_title(value)
  end

  def content=(value)
    super
    refresh_plain_text
  end

  def summary=(value)
    super
    refresh_plain_text
  end

  def original?
    duplicate_of_id.nil?
  end

  def duplicate?
    !original?
  end

  private

  # The text a reader sees in the Aggregate Feed (content, falling back to
  # summary) as plain text, for the Keyword index.
  def refresh_plain_text
    self.plain_text = self.class.plain_text_of(content.presence || summary)
  end

  def duplicate_of_is_an_original_from_another_source
    return if duplicate_of.nil?

    errors.add(:duplicate_of, "must be an Original, not a Duplicate") if duplicate_of.duplicate?
    errors.add(:duplicate_of, "must be from a different Source") if duplicate_of.source_id == source_id
  end
end
