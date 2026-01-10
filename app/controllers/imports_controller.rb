# app/controllers/imports_controller.rb
require "csv"

class ImportsController < ApplicationController
  def new
    @recent_imports = TransactionImport.order(created_at: :desc).limit(10)
  end

  def transactions
    file = params[:file]
    account_name = params[:account_name]

    unless file.present?
      redirect_to new_import_path, alert: "Please upload a CSV file" and return
    end

    if account_name.blank?
      redirect_to new_import_path, alert: "Account name is required" and return
    end

  unknown_category = Category.find_or_create_by!(name: "Unknown")
  categories = Category.all.to_a

  created_count = 0
  skipped_count = 0
  duplicates = []

    CSV.foreach(file.path) do |row|
      date, description, expense, income, _card = row
      amount_raw = expense.presence || income.presence
      next unless amount_raw

      # Normalize fields
      amount_value = amount_raw.to_f
      transaction_type = expense.present? ? "expense" : "income"
      parsed_date = begin
        DateTime.parse(date.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      category =
        categories.find { |cat| cat.keyword_list.any? { |k| description.to_s.downcase.include?(k.downcase) } } ||
        unknown_category

      # Compute UID to avoid duplicates: based on datetime, amount, and description
      uid = Transaction.generate_uid(name: description, amount: amount_value, datetime: parsed_date || Time.current)

      # If a transaction with same UID already exists, record as a potential duplicate
      if Transaction.exists?(uid: uid)
        duplicates << {
          uid: uid,
          name: description,
          amount: amount_value,
          transaction_type: transaction_type,
          account_name: account_name,
          category_id: category.id,
          category_name: category.name,
          created_at: parsed_date&.to_s,
          existing_transaction_id: Transaction.find_by(uid: uid)&.id
        }
        next
      end

      Transaction.create!(
        name: description,
        amount: amount_value,
        transaction_type: transaction_type,
        account_name: account_name,
        category: category,
        created_at: parsed_date,
        uid: uid
      )
      created_count += 1
    end

    # If there are duplicates, store them in session and redirect to the duplicates review page
    if duplicates.any?
      session[:import_duplicates] = duplicates
      session[:import_meta] = { account_name: account_name, filename: file.respond_to?(:original_filename) ? file.original_filename : nil, created_count: created_count, skipped_count: skipped_count }
      redirect_to duplicates_imports_path and return
    end

    # No duplicates -> record the import and redirect back
    notice_msg = "Transactions imported successfully"
    details = []
    details << "#{created_count} #{created_count == 1 ? 'new record' : 'new records'}" if created_count > 0
    details << "#{skipped_count} #{skipped_count == 1 ? 'duplicate skipped' : 'duplicates skipped'}" if skipped_count > 0
    notice_msg += " — " + details.join(', ') unless details.empty?

    begin
      TransactionImport.create!(account_name: account_name, filename: file.respond_to?(:original_filename) ? file.original_filename : nil, created_count: created_count, skipped_count: skipped_count)
    rescue => e
      Rails.logger.warn "Failed to create TransactionImport record: #{e.message}"
    end

    redirect_to transactions_path, notice: notice_msg
  end

  # GET /imports/duplicates
  def duplicates
    @duplicates = session[:import_duplicates] || []
    @meta = session[:import_meta] || {}
    render :duplicates
  end

  # POST /imports/resolve_duplicate
  # params: index (integer), decision ('keep' or 'ignore')
  def resolve_duplicate
  uid = params[:uid].to_s
  decision = params[:decision].to_s
  duplicates = session[:import_duplicates] || []
    meta = session[:import_meta] || { 'created_count' => 0, 'skipped_count' => 0 }

    item = duplicates.find { |d| d['uid'].to_s == uid }
    unless item
      render json: { error: 'invalid uid' }, status: 422 and return
    end

    if decision == 'keep'
      # create transaction only if UID still doesn't exist
      unless Transaction.exists?(uid: item['uid'])
        tx = Transaction.create(
          name: item['name'],
          amount: item['amount'],
          transaction_type: item['transaction_type'],
          account_name: item['account_name'],
          category_id: item['category_id'],
          created_at: item['created_at'],
          uid: item['uid']
        )
        meta['created_count'] = (meta['created_count'] || 0) + (tx.persisted? ? 1 : 0)
      end
    else
      # ignore duplicate
      meta['skipped_count'] = (meta['skipped_count'] || 0) + 1
    end

  # remove the processed item
  duplicates = duplicates.reject { |d| d['uid'].to_s == uid }
    session[:import_duplicates] = duplicates
    session[:import_meta] = meta

    render json: { remaining: duplicates.length, meta: meta }
  end

  # POST /imports/finish_import
  def finish_import
    meta = session.delete(:import_meta) || {}
    # persist TransactionImport record
    begin
      TransactionImport.create!(account_name: meta['account_name'], filename: meta['filename'], created_count: meta['created_count'] || 0, skipped_count: meta['skipped_count'] || 0)
    rescue => e
      Rails.logger.warn "Failed to create TransactionImport record: #{e.message}"
    end
    session.delete(:import_duplicates)
    notice_msg = "Import processed"
    details = []
    details << "#{meta['created_count']} new records" if (meta['created_count'] || 0) > 0
    details << "#{meta['skipped_count']} duplicates skipped" if (meta['skipped_count'] || 0) > 0
    notice_msg += " — " + details.join(', ') unless details.empty?
    redirect_to transactions_path, notice: notice_msg
  end
end
