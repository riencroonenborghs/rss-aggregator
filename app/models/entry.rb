# == Schema Information
#
# Table name: entries
# Database name: primary
#
#  id              :integer          not null, primary key
#  author          :string
#  content         :text
#  first_seen_at   :datetime         not null
#  identifier      :string           not null
#  link            :string
#  normalised_link :string
#  published_at    :datetime         not null
#  summary         :text
#  title           :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  duplicate_of_id :integer
#  source_id       :integer          not null
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

  def link=(value)
    super
    self.normalised_link = self.class.normalise_link(value)
  end

  def original?
    duplicate_of_id.nil?
  end

  def duplicate?
    !original?
  end

  private

  def duplicate_of_is_an_original_from_another_source
    return if duplicate_of.nil?

    errors.add(:duplicate_of, "must be an Original, not a Duplicate") if duplicate_of.duplicate?
    errors.add(:duplicate_of, "must be from a different Source") if duplicate_of.source_id == source_id
  end
end
