class TransactionsController < ApplicationController
  before_action :set_transaction,
                only: %i[ show edit update destroy assign_category ],
                if: -> { params[:id].present? }

  before_action :load_categories, only: %i[ new edit create update ]

  # GET /transactions or /transactions.json
  def index
    @transactions = Transaction.all.includes(:category)
    @categories = Category.order(:name)
    # available account names for filter (compact removes nils)
    @accounts = Transaction.distinct.pluck(:account_name).compact.map(&:to_s).uniq.sort

    # Search by name
    if params[:q].present?
      q = params[:q].to_s.downcase
      @transactions = @transactions.where("LOWER(name) LIKE ?", "%#{q}%")
    end

    # Date range filtering (use created_at as the transaction date)
    if params[:start_date].present?
      begin
        start_date = Date.parse(params[:start_date])
        @transactions = @transactions.where("created_at >= ?", start_date.beginning_of_day)
      rescue ArgumentError
        # ignore invalid date
      end
    end

    if params[:end_date].present?
      begin
        end_date = Date.parse(params[:end_date])
        @transactions = @transactions.where("created_at <= ?", end_date.end_of_day)
      rescue ArgumentError
        # ignore invalid date
      end
    end

    # Sorting by date: default to desc
    sort = params[:sort].to_s.downcase == 'asc' ? :asc : :desc
    @transactions = @transactions.order(created_at: sort)

    # Filter by category if selected
    if params[:category_id].present?
      @transactions = @transactions.where(category_id: params[:category_id])
    end

    # Filter by account name if provided
    if params[:account_name].present?
      @transactions = @transactions.where(account_name: params[:account_name])
    end

    # Count results for the view (after filters applied)
    @results_count = @transactions.count
  end

  # GET /uncategorized
  def uncategorized
    @unknown = Category.find_or_create_by!(name: "Unknown")
    @transactions = Transaction.where(category: @unknown).includes(:category)
    @categories = Category.where.not(id: @unknown.id).order(:name)
  end

  # PATCH /transactions/:id/assign_category
  # Expects { category_id: <id> } via JSON; returns JSON
  def assign_category
    set_transaction if @transaction.nil? && params[:id].present?
    category = Category.find(params[:category_id])

    ActiveRecord::Base.transaction do
      @transaction.update!(category: category)

      # Add transaction name snippet (first word, truncated to 12 chars) to category keywords if not present
      kws = category.keyword_list
      name = @transaction.name.to_s.strip
      unless name.blank?
        first_word = name.split(/\s+/).first || ''
        snippet = first_word.length <= 12 ? first_word : first_word[0,12]
        snippet = snippet.to_s.strip
        unless snippet.blank? || kws.map(&:downcase).include?(snippet.downcase)
          kws << snippet
          category.update!(keywords: kws)
        end
      end
    end

    # After updating the category and its keywords, callbacks may have reassigned
    # other transactions that match the new keywords. Render the updated
    # uncategorized list HTML so the client can refresh that pane.
    unknown = Category.find_by(name: "Unknown")
    remaining = unknown ? Transaction.where(category: unknown).includes(:category) : Transaction.none
    # force HTML format when rendering the partial string to avoid lookup for JSON variants
    remaining_html = render_to_string(partial: 'transactions/uncategorized_list', locals: { transactions: remaining }, formats: [:html])

    render json: { success: true, transaction_id: @transaction.id, category_name: category.name, remaining_html: remaining_html }
  rescue ActiveRecord::RecordNotFound => e
    render json: { success: false, error: e.message }, status: :not_found
  rescue ActiveRecord::RecordInvalid => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    # unexpected server error: log and return JSON so client-side can present a helpful message
    Rails.logger.error "assign_category failed: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    render json: { success: false, error: "Server error while assigning category: #{e.message}" }, status: :internal_server_error
  end

  # GET /transactions/1 or /transactions/1.json
  def show
    Rails.logger.debug "SHOW ACTION HIT, id=#{params[:id].inspect}"
  end

  # GET /transactions/new
  def new
    @transaction = Transaction.new
  end

  # GET /transactions/1/edit
  def edit
  end

  # POST /transactions or /transactions.json
  def create
    @transaction = Transaction.new(transaction_params)

    respond_to do |format|
      if @transaction.save
        format.html { redirect_to @transaction, notice: "Transaction was successfully created." }
        format.json { render :show, status: :created, location: @transaction }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @transaction.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /transactions/1 or /transactions/1.json
  def update
    respond_to do |format|
      if @transaction.update(transaction_params)
        format.html { redirect_to @transaction, notice: "Transaction was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @transaction }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @transaction.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /transactions/1 or /transactions/1.json
  def destroy
    @transaction.destroy!

    respond_to do |format|
      format.html { redirect_to transactions_path, notice: "Transaction was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    def set_transaction
      Rails.logger.debug "SET_TRANSACTION id=#{params[:id].inspect}"
      @transaction = Transaction.find(params[:id])
    end


    def load_categories
      @categories = Category.order(:name)
    end

    def transaction_params
      params.require(:transaction).permit(:name, :amount, :transaction_type, :account_name, :category_id, :to_be_reimbursed)
    end
end
