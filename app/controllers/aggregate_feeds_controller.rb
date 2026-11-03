# Serves the Aggregate Feed. Inherits from ActionController::Base rather than
# ApplicationController so the modern-browser gate never blocks feed readers.
class AggregateFeedsController < ActionController::Base
  PAGE_SIZE = 100

  def show
    @entries = Entry.includes(:source).newest_first.limit(PAGE_SIZE)
  end
end
