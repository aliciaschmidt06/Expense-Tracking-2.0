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
    # load categories for dashboard filter
    @categories = Category.order(:name)
  end

  # GET /insights
  def insights
    # reuse index's data for defaults
    first_ts = Transaction.minimum(:created_at)
    last_ts = Transaction.maximum(:created_at)

    if first_ts && last_ts
      @data_available = true
      @range_start = first_ts.to_date
      @range_end = last_ts.to_date
      @stale_days = (Date.current - @range_end).to_i
      @stale_days = 0 if @stale_days.negative?
    else
      @data_available = false
      @range_start = nil
      @range_end = nil
      @stale_days = nil
    end

    @categories = Category.order(:name)
  end

  # GET /spending_breakdown
  def spending_breakdown
    # reuse index defaults
    first_ts = Transaction.minimum(:created_at)
    last_ts = Transaction.maximum(:created_at)

    if first_ts && last_ts
      @data_available = true
      @range_start = first_ts.to_date
      @range_end = last_ts.to_date
      @stale_days = (Date.current - @range_end).to_i
      @stale_days = 0 if @stale_days.negative?
    else
      @data_available = false
      @range_start = nil
      @range_end = nil
      @stale_days = nil
    end

    @categories = Category.where.not(target_percentage: nil).where('target_percentage > 0').order(:name)
  end

  # GET /dashboard_data.json
  def dashboard_data
    # parse filters
    # safe parsing of optional dates
    start_date = nil
    if params[:start_date].present?
      begin
        start_date = Date.parse(params[:start_date])
      rescue ArgumentError, TypeError
        start_date = nil
      end
    end

    end_date = nil
    if params[:end_date].present?
      begin
        end_date = Date.parse(params[:end_date])
      rescue ArgumentError, TypeError
        end_date = nil
      end
    end
    category_id = params[:category_id].present? ? params[:category_id].to_i : nil

    # sensible defaults: last 12 months if not provided
    if start_date.nil? || end_date.nil?
      end_date ||= Date.current
      start_date ||= (end_date << 11).beginning_of_month.to_date
    end

    scope = Transaction.all
    scope = scope.where(category_id: category_id) if category_id.present?
    scope = scope.where('created_at >= ?', start_date.beginning_of_day) if start_date.present?
    scope = scope.where('created_at <= ?', end_date.end_of_day) if end_date.present?

    # load and group in Ruby (DB-agnostic)
    txs = scope.select(:amount, :created_at).to_a
    # build month buckets from start_date to end_date
    months = []
    cursor = start_date.beginning_of_month
    end_month = end_date.beginning_of_month
    while cursor <= end_month
      months << cursor
      cursor = cursor.next_month
    end

    totals = months.map do |m|
      bucket = txs.select { |t| t.created_at.to_date.beginning_of_month == m }
      bucket.sum { |t| (t.amount || 0).to_f }
    end

    labels = months.map { |m| m.strftime('%b %Y') }

    # build category breakdown for the selected period (ignoring category_id filter)
    period_scope = Transaction.all
    period_scope = period_scope.where('created_at >= ?', start_date.beginning_of_day) if start_date.present?
    period_scope = period_scope.where('created_at <= ?', end_date.end_of_day) if end_date.present?
    total_sum = period_scope.sum(:amount).to_f

    if params[:include_zero].present?
      categories_scope = Category.order(:name)
    else
      categories_scope = Category.where.not(target_percentage: nil).where('target_percentage > 0').order(:name)
    end

    categories = categories_scope.map do |c|
      c_sum = period_scope.where(category_id: c.id).sum(:amount).to_f
      actual_pct = total_sum > 0 ? (c_sum / total_sum * 100.0) : 0.0
      {
        id: c.id,
        name: c.name,
        target_percentage: c.target_percentage.to_f,
        actual_percentage: actual_pct.round(2),
        sum: c_sum.round(2)
      }
    end

    render json: { labels: labels, totals: totals, breakdown: categories, total_sum: total_sum.round(2) }
  end

  # GET /dashboard_category_transactions.json
  def dashboard_category_transactions
    category_id = params[:category_id].present? ? params[:category_id].to_i : nil

    # parse dates safely (reuse logic)
    start_date = nil
    if params[:start_date].present?
      begin
        start_date = Date.parse(params[:start_date])
      rescue ArgumentError, TypeError
        start_date = nil
      end
    end

    end_date = nil
    if params[:end_date].present?
      begin
        end_date = Date.parse(params[:end_date])
      rescue ArgumentError, TypeError
        end_date = nil
      end
    end

    scope = Transaction.all
    scope = scope.where(category_id: category_id) if category_id.present?
    scope = scope.where('created_at >= ?', start_date.beginning_of_day) if start_date.present?
    scope = scope.where('created_at <= ?', end_date.end_of_day) if end_date.present?

    txs = scope.order(created_at: :desc).limit(1000).map do |t|
      {
        id: t.id,
        name: t.name,
        amount: t.amount.to_f,
        account_name: t.account_name,
        created_at: t.created_at
      }
    end

    render json: { transactions: txs }
  end

  # GET /spending_breakdown/export.csv
  def spending_breakdown_export
    # parse dates safely
    start_date = nil
    if params[:start_date].present?
      begin
        start_date = Date.parse(params[:start_date])
      rescue ArgumentError, TypeError
        start_date = nil
      end
    end

    end_date = nil
    if params[:end_date].present?
      begin
        end_date = Date.parse(params[:end_date])
      rescue ArgumentError, TypeError
        end_date = nil
      end
    end

    # sensible defaults: last 12 months
    if start_date.nil? || end_date.nil?
      end_date ||= Date.current
      start_date ||= (end_date << 11).beginning_of_month.to_date
    end

    period_scope = Transaction.all
    period_scope = period_scope.where('created_at >= ?', start_date.beginning_of_day) if start_date.present?
    period_scope = period_scope.where('created_at <= ?', end_date.end_of_day) if end_date.present?

    total_sum = period_scope.sum(:amount).to_f

    include_zero = params[:include_zero].present?
    categories_scope = include_zero ? Category.order(:name) : Category.where.not(target_percentage: nil).where('target_percentage > 0').order(:name)

    require 'csv'
    csv = CSV.generate(headers: false) do |csv|
      csv << ["Spending Plan"]
      # print statement date or period
      if start_date && end_date && start_date.month == end_date.month && start_date.year == end_date.year
        csv << ["Statement date: #{start_date.strftime('%B %Y')}"]
      else
        csv << ["Period: #{start_date.strftime('%Y-%m-%d')} to #{end_date.strftime('%Y-%m-%d')}"]
      end
      csv << []

      categories_scope.each do |c|
        c_sum = period_scope.where(category_id: c.id).sum(:amount).to_f
        actual_pct = total_sum > 0 ? (c_sum / total_sum * 100.0) : 0.0
        target = c.target_percentage.to_f
        csv << ["#{c.name}: Target #{target.round(2)}%, Actual #{actual_pct.round(2)}%"]
        csv << ["Date", "Name", "Account", "Amount"]
        txs = period_scope.where(category_id: c.id).order(created_at: :desc)
        txs.each do |t|
          csv << [t.created_at.to_date.strftime('%Y-%m-%d'), t.name, t.account_name, sprintf('%.2f', t.amount.to_f)]
        end
        csv << []
      end
    end

    filename = "spending_plan_#{Time.current.strftime('%Y%m%d%H%M%S')}.csv"
    send_data csv, filename: filename, type: 'text/csv; charset=utf-8'
  end
end
