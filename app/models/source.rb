# == Schema Information
#
# Table name: sources
#
#  id         :integer          not null, primary key
#  name       :string
#  url        :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_sources_on_url  (url) UNIQUE
#
# An external RSS or Atom feed that the aggregator pulls Entries from.
class Source < ApplicationRecord
  has_many :entries, dependent: :delete_all

  validates :url, presence: true, uniqueness: true,
    format: { with: %r{\Ahttps?://}i, message: "must start with http:// or https://" }

  # Fetches the Source once and returns the number of new Entries stored.
  def fetch
    SourceFetcher.perform(self).new_entries_count
  end

  def display_name
    name.presence || url
  end
end
