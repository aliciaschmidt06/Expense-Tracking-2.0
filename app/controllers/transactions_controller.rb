class TransactionsController < ApplicationController
  before_action :set_transaction, only: %i[ show edit update destroy ]
  before_action :load_categories, only: %i[ new edit create update ]

  # GET /transactions or /transactions.json
  def index
    @transactions = Transaction.all.includes(:category)
    @categories = Category.order(:name)

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

    # Count results for the view (after filters applied)
    @results_count = @transactions.count
  end

  # GET /transactions/1 or /transactions/1.json
  def show
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
      @transaction = Transaction.find(params[:id])
    end

    def load_categories
      @categories = Category.order(:name)
    end

    def transaction_params
      params.require(:transaction).permit(:name, :amount, :transaction_type, :account_name, :category_id, :to_be_reimbursed)
    end
end
