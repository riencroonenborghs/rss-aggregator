# frozen_string_literal: true

# Enqueues one FetchSourceJob per Source, so that a slow or broken Source
# can't hold up the others. Scheduled in config/recurring.yml.
class FetchAllSourcesJob < ApplicationJob
  queue_as :default

  def perform
    Source.find_each { |source| FetchSourceJob.perform_later(source) }
  end
end
