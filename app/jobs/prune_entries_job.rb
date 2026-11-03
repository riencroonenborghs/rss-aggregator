# frozen_string_literal: true

# Deletes Entries older than the retention period. Scheduled daily in
# config/recurring.yml.
class PruneEntriesJob < ApplicationJob
  queue_as :default

  def perform
    EntryPruner.perform
  end
end
