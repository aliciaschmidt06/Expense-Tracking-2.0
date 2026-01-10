class HomeController < ApplicationController
  def index
    # compute available data range from transactions
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
    # load categories for dashboard filter
    @categories = Category.order(:name)
    # helpful counts for the landing page
    @transactions_count = Transaction.count
    @categorized_count = Transaction.where.not(category_id: nil).count

  # boolean helpers for view logic
  @has_transactions = @transactions_count > 0
  # count categories excluding the Unknown fallback (case-insensitive)
  @real_categories_count = Category.where.not("LOWER(name) = ?", 'unknown').count
  @has_real_categories = @real_categories_count > 0

    # detect incomplete categories:
    # - Unknown category is allowed to have no keywords
    # - Income and Ignore are allowed to have no target
    @incomplete_categories = @categories.select do |c|
      kws = c.keyword_list
      lname = c.name.to_s.downcase

      # missing keywords unless this is the Unknown category
      missing_keywords = (kws.empty? && lname != 'unknown')

      comp = c.respond_to?(:target_comparison) ? c.target_comparison.to_s : nil
  # Income, Ignore and Unknown are allowed to have no target; otherwise require a positive target unless explicitly not_applicable
  allowed_no_target = %w[income ignore unknown].include?(lname)
      missing_target = (!allowed_no_target) && (comp != 'not_applicable') && (c.target_percentage.nil? || c.target_percentage.to_f <= 0)

      missing_keywords || missing_target
    end
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

    period_scope = Transaction.all
    period_scope = period_scope.where('created_at >= ?', start_date.beginning_of_day) if start_date.present?
    period_scope = period_scope.where('created_at <= ?', end_date.end_of_day) if end_date.present?
    ignore = Category.find_by(name: 'Ignore')
    period_scope = period_scope.where.not(category_id: ignore.id) if ignore.present?

    total_sum = period_scope.sum(:amount).to_f
    income_total = period_scope.where(transaction_type: Transaction.transaction_types[:income]).sum(:amount).to_f

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

    render json: { labels: labels, totals: totals, breakdown: categories, total_sum: total_sum.round(2), income_total: income_total.round(2) }
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
        transaction_type: t.transaction_type,
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

    # period scope for listing transactions
    period_scope = Transaction.all
    period_scope = period_scope.where('created_at >= ?', start_date.beginning_of_day) if start_date.present?
    period_scope = period_scope.where('created_at <= ?', end_date.end_of_day) if end_date.present?

    # find special categories
    income_cat = Category.where('LOWER(name) = ?', 'income').first
    ignore_cat = Category.where('LOWER(name) = ?', 'ignore').first
    unknown_cat = Category.where('LOWER(name) = ?', 'unknown').first

    # calculation scope: exclude Ignore and Unknown
    calc_scope = Transaction.all
    calc_scope = calc_scope.where('created_at >= ?', start_date.beginning_of_day) if start_date.present?
    calc_scope = calc_scope.where('created_at <= ?', end_date.end_of_day) if end_date.present?
    calc_scope = calc_scope.where.not(category_id: ignore_cat.id) if ignore_cat.present?
    calc_scope = calc_scope.where.not(category_id: unknown_cat.id) if unknown_cat.present?

    # base for target math is Income transactions only
    income_sum = income_cat.present? ? calc_scope.where(category_id: income_cat.id).sum(:amount).to_f : 0.0
    base_sum = income_sum

    total_sum = period_scope.sum(:amount).to_f

    # build ordered category list (income first)
    base_cats = Category.all.to_a
    base_cats.compact!
    ordered = []
    ordered << income_cat if income_cat.present?
    normal_cats = base_cats.reject { |c| [income_cat&.id, ignore_cat&.id, unknown_cat&.id].compact.include?(c.id) }
    normal_cats = normal_cats.sort_by { |c| c.name.to_s.downcase }
    ordered.concat(normal_cats)
    ordered << ignore_cat if ignore_cat.present?
    ordered << unknown_cat if unknown_cat.present?

    require 'csv'
    csv = CSV.generate(headers: false) do |csv|
      csv << ["Spending Plan"]
      # human readable statement date or period
      if start_date && end_date && start_date.month == end_date.month && start_date.year == end_date.year
        csv << ["Statement date: #{start_date.strftime('%B %Y')}"]
      else
        csv << ["Period: #{start_date.strftime('%Y-%m-%d')} to #{end_date.strftime('%Y-%m-%d')}"]
      end
      csv << []

      ordered.each do |c|
        next unless c
        c_sum = period_scope.where(category_id: c.id).sum(:amount).to_f

        # Build subtitle similar to the page
        lname = c.name.to_s.downcase
        is_income = lname == 'income'
        is_ignore = lname == 'ignore'
        is_unknown = lname == 'unknown'

        if is_income || is_ignore || is_unknown
          csv << ["#{c.name}: Total #{sprintf('%.2f', c_sum)}"]
        else
          target_pct = c.target_percentage.to_f
          target_amount = base_sum * (target_pct / 100.0)
          actual_pct = base_sum > 0 ? (c_sum / base_sum * 100.0) : 0.0
          # include comparison label if present
          comp = c.respond_to?(:target_comparison) ? c.target_comparison.to_s : 'equal_to'
          comp_label = case comp
                       when 'less_than' then 'Less than'
                       when 'greater_than' then 'Greater than'
                       when 'equal_to' then 'Equal to'
                       else 'Target'
                       end
          cmp_text = comp == 'not_applicable' ? 'Not applicable' : "#{comp_label} #{target_pct}% target"
          csv << ["#{c.name}: Target: #{sprintf('%.2f', target_amount)} (#{target_pct.round(2)}%) — Actual: #{sprintf('%.2f', c_sum)} (#{actual_pct.round(2)}%) — #{cmp_text}"]
        end

        # table header matches page (Date, Name, Account, Type, Amount)
        csv << ["Date", "Name", "Account", "Type", "Amount"]
        txs = period_scope.where(category_id: c.id).order(created_at: :desc)
        txs.each do |t|
          type_label = t.transaction_type == Transaction.transaction_types[:income] ? 'Income' : 'Expense'
          csv << [t.created_at.to_date.strftime('%Y-%m-%d'), t.name, t.account_name, type_label, sprintf('%.2f', t.amount.to_f)]
        end
        csv << []
      end
    end

    filename = "spending_plan_#{Time.current.strftime('%Y%m%d%H%M%S')}.csv"
    send_data csv, filename: filename, type: 'text/csv; charset=utf-8'
  end

  # GET /spending_breakdown/data.json
  def spending_breakdown_data
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

    # full scope for displaying transaction lists
    full_scope = Transaction.all
    full_scope = full_scope.where('created_at >= ?', start_date.beginning_of_day) if start_date.present?
    full_scope = full_scope.where('created_at <= ?', end_date.end_of_day) if end_date.present?

    # find special categories (case-insensitive)
    income_cat = Category.where('LOWER(name) = ?', 'income').first
    ignore_cat = Category.where('LOWER(name) = ?', 'ignore').first
    unknown_cat = Category.where('LOWER(name) = ?', 'unknown').first

    # calculation scope: exclude Ignore and Unknown categories entirely from calculations
    calc_scope = Transaction.all
    calc_scope = calc_scope.where('created_at >= ?', start_date.beginning_of_day) if start_date.present?
    calc_scope = calc_scope.where('created_at <= ?', end_date.end_of_day) if end_date.present?
    calc_scope = calc_scope.where.not(category_id: ignore_cat.id) if ignore_cat.present?
    calc_scope = calc_scope.where.not(category_id: unknown_cat.id) if unknown_cat.present?

    # base amount for targets/percentages must be Income transactions only (per request)
    income_sum = income_cat.present? ? calc_scope.where(category_id: income_cat.id).sum(:amount).to_f : 0.0
    base_sum = income_sum

    # still compute total visible sum for display, but don't use it for target math
    total_sum = full_scope.sum(:amount).to_f

    # Build ordered category list: income first, then normal categories, then ignore & unknown at bottom
    base_cats = Category.all.to_a
    base_cats.compact!

    ordered = []
    ordered << income_cat if income_cat.present?

    normal_cats = base_cats.reject { |c| [income_cat&.id, ignore_cat&.id, unknown_cat&.id].compact.include?(c.id) }
    normal_cats = normal_cats.sort_by { |c| c.name.to_s.downcase }
    ordered.concat(normal_cats)
    ordered << ignore_cat if ignore_cat.present?
    ordered << unknown_cat if unknown_cat.present?

    cats = ordered.map do |c|
      next unless c
      # use full_scope to show transactions for each category (so Ignore/Unknown still list their txs)
      txs = full_scope.where(category_id: c.id).order(created_at: :desc).map do |t|
        {
          id: t.id,
          name: t.name,
          amount: t.amount.to_f,
          transaction_type: t.transaction_type,
          account_name: t.account_name,
          created_at: t.created_at
        }
      end

      c_sum = txs.sum { |t| t[:amount].to_f }
      target_pct = c.target_percentage.to_f
      # target/actual calculations use base_sum (income_sum) per new requirement
      target_amount = base_sum * (target_pct / 100.0)
      actual_pct = base_sum > 0 ? (c_sum / base_sum * 100.0) : 0.0

      {
        id: c.id,
        name: c.name,
        target_percentage: target_pct.round(2),
        target_amount: target_amount.round(2),
        actual_percentage: actual_pct.round(2),
        sum: c_sum.round(2),
        target_comparison: c.respond_to?(:target_comparison) ? c.target_comparison.to_s : 'equal_to',
        transactions: txs
      }
    end.compact

    render json: { total_sum: total_sum.round(2), income_summary: { amount: income_sum.round(2), note: 'based on your Income category (keyword-defined) — calculations use Income only; Ignore/Unknown are excluded' }, categories: cats }
  end
end
