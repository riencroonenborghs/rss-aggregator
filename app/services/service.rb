# Base for service objects.
#
# Including it adds a class-level `.perform(...)`, which builds an instance with
# the given arguments, calls its `#perform`, and returns the instance, so that
# results are read from the service's own readers. Every service must
# implement `#perform`.
#
# It also gives each service a SemanticLogger named after its class, through
# the private `log_info`, `log_warn` and `log_error` helpers.
module Service
  extend ActiveSupport::Concern

  included do
    include SemanticLogger::Loggable
  end

  class_methods do
    def perform(...)
      new(...).tap(&:perform)
    end
  end

  def perform
    raise NotImplementedError, "#{self.class.name} must implement #perform"
  end

  private

  def log_info(message, **payload)
    logger.info(message, payload.presence)
  end

  def log_warn(message, **payload)
    logger.warn(message, payload.presence)
  end

  def log_error(message, exception = nil, **payload)
    logger.error(message, payload.presence, exception)
  end
end
