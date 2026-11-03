# frozen_string_literal: true

# == Schema Information
#
# Table name: sources
# Database name: primary
#
#  id              :integer          not null, primary key
#  etag            :string
#  last_error      :text
#  last_error_at   :datetime
#  last_fetched_at :datetime
#  last_modified   :string
#  name            :string
#  url             :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
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

  # Fetches the Source once. Returns the SourceFetcher, which says whether it
  # worked and how many new Entries were stored.
  def fetch
    SourceFetcher.perform(self)
  end

  def display_name
    name.presence || url
  end
end
