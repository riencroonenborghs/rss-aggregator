# Fetches a single Source. Failures are recorded on the Source by the
# SourceFetcher, so this job doesn't raise or retry on its own; the next
# scheduled cycle tries again.
class FetchSourceJob < ApplicationJob
  queue_as :default

  # The Source was removed after the job was enqueued.
  discard_on ActiveJob::DeserializationError

  def perform(source)
    SourceFetcher.perform(source)
  end
end
