class HomeController < ApplicationController
  def index
    # compute available data range from transactions
    first_ts = Transaction.minimum(:created_at)
    last_ts = Transaction.maximum(:created_at)

    if first_ts && last_ts
      @data_available = true
      @range_start = first_ts.to_date
      @range_end = last_ts.to_date

      # how many days stale is the data relative to today
      @stale_days = (Date.current - @range_end).to_i
      @stale_days = 0 if @stale_days.negative?
    else
      @data_available = false
      @range_start = nil
      @range_end = nil
      @stale_days = nil
    end
  end
end
