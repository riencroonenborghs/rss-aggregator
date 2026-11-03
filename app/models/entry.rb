# == Schema Information
#
# Table name: entries
#
#  id            :integer          not null, primary key
#  author        :string
#  content       :text
#  first_seen_at :datetime         not null
#  identifier    :string           not null
#  link          :string
#  published_at  :datetime         not null
#  summary       :text
#  title         :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  source_id     :integer          not null
#
# Indexes
#
#  index_entries_on_published_at              (published_at)
#  index_entries_on_source_id                 (source_id)
#  index_entries_on_source_id_and_identifier  (source_id,identifier) UNIQUE
#
# Foreign Keys
#
#  source_id  (source_id => sources.id)
#
# A single piece of content pulled from a Source and stored by the aggregator.
class Entry < ApplicationRecord
  RETENTION_PERIOD = 30.days

  belongs_to :source

  scope :newest_first, -> { order(published_at: :desc, id: :desc) }
end
