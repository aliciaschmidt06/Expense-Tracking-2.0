# app/controllers/imports_controller.rb
require "csv"
require 'securerandom'

class ImportsController < ApplicationController
  def new
    # Only show recent imports if there are any transactions in the system.
    # When all transactions are deleted we don't want to display a history
    # of previous imports because it can be confusing (no transactions exist).
    if Transaction.exists?
      @recent_imports = TransactionImport.order(created_at: :desc).limit(10)
    else
      @recent_imports = []
    end
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

    # Set up helpers and record for this import
    unknown_category = Category.find_or_create_by!(name: "Unknown")
    categories = Category.all.to_a

    created_count = 0
    skipped_count = 0
    sequence = 0

    # Create an import/session record we can tag transactions with
    begin
      tx_import = TransactionImport.create!(account_name: account_name, filename: file.respond_to?(:original_filename) ? file.original_filename : nil, created_count: 0, skipped_count: 0)
    rescue => e
      Rails.logger.warn("Failed to create TransactionImport at start of import: #{e.message}")
      tx_import = nil
    end

    CSV.foreach(file.path).with_index(1) do |row, row_number|
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

      # Compute content UID (based on date, name, amounts) used for cross-session duplicate detection
      date_part = parsed_date ? parsed_date.to_date : Time.current.to_date
      amount_out = transaction_type == "expense" ? amount_value : 0
      amount_in = transaction_type == "income" ? amount_value : 0
      content_uid = Transaction.generate_uid(name: description, date: date_part, amount_out: amount_out, amount_in: amount_in)

      # If another session (import) for the same account already contains this content, skip it
      if Transaction.where(content_uid: content_uid, account_name: account_name).where.not(transaction_import_id: tx_import&.id).exists?
        Rails.logger.warn({ event: "import_skip_cross_session_duplicate", row: row_number, uid: content_uid, account: account_name, name: description.to_s }.to_json)
        skipped_count += 1
        next
      end

      # Create a stored UID unique in the DB by including the import id and a sequence number
      created = false
      attempt = 0
      while !created && attempt < 5
        attempt += 1
        sequence += 1
        stored_uid = "#{content_uid}-i#{tx_import&.id || 'local'}-s#{sequence}"
        begin
          Transaction.create!(
            name: description,
            amount: amount_value,
            transaction_type: transaction_type,
            account_name: account_name,
            category: category,
            created_at: parsed_date,
            uid: stored_uid,
            content_uid: content_uid,
            transaction_import_id: tx_import&.id,
            import_sequence: sequence
          )
          created = true
          created_count += 1
        rescue ActiveRecord::RecordInvalid => e
          # Collision on generated stored UID (very unlikely) — retry with next sequence
          if e.message =~ /Uid has already been taken/i
            Rails.logger.warn("UID collision creating stored_uid=#{stored_uid}, retrying (attempt=#{attempt})")
            next
          else
            raise
          end
        end
      end

      unless created
        Rails.logger.warn({ event: "import_failed_create", row: row_number, uid: content_uid }.to_json)
        skipped_count += 1
      end
    end

    # No duplicates -> record the import and redirect back
    notice_msg = "Transactions imported successfully"
    details = []
    details << "#{created_count} #{created_count == 1 ? 'new record' : 'new records'}" if created_count > 0
    details << "#{skipped_count} #{skipped_count == 1 ? 'duplicate skipped' : 'duplicates skipped'}" if skipped_count > 0
    notice_msg += " — " + details.join(', ') unless details.empty?

    begin
      if tx_import
        tx_import.update!(created_count: created_count, skipped_count: skipped_count)
      else
        TransactionImport.create!(account_name: account_name, filename: file.respond_to?(:original_filename) ? file.original_filename : nil, created_count: created_count, skipped_count: skipped_count)
      end
    rescue => e
      Rails.logger.warn "Failed to persist TransactionImport record: #{e.message}"
    end

    # Redirect back to the Upload page so the user sees the success message
    # and the recent uploads table on the same page.
    redirect_to new_import_path, notice: notice_msg
  end

  # GET /imports/duplicates
  def duplicates
    # prefer the server-side cache key to avoid cookie overflow; fall back to old session storage for compatibility
    if session[:import_duplicates_key].present?
      @duplicates = Rails.cache.read(session[:import_duplicates_key]) || []
    else
      @duplicates = session[:import_duplicates] || []
    end
    @meta = session[:import_meta] || {}
    render :duplicates
  end

  # POST /imports/resolve_duplicate
  # params: index (integer), decision ('keep' or 'ignore')
  def resolve_duplicate
    uid = params[:uid].to_s
    decision = params[:decision].to_s

    # load duplicates from cache if available, otherwise fall back to session
    duplicates = if session[:import_duplicates_key].present?
      Rails.cache.read(session[:import_duplicates_key]) || []
    else
      session[:import_duplicates] || []
    end

    meta = session[:import_meta] || { 'created_count' => 0, 'skipped_count' => 0 }

    item = duplicates.find { |d| d['uid'].to_s == uid }
    unless item
      render json: { error: 'invalid uid' }, status: 422 and return
    end

    if decision == 'keep'
      unless Transaction.exists?(uid: item['uid'])
        incoming = item['incoming'] || item
        tx = Transaction.create(
          name: incoming['name'],
          amount: incoming['amount'],
          transaction_type: incoming['transaction_type'],
          account_name: incoming['account_name'],
          category_id: incoming['category_id'],
          created_at: incoming['created_at'],
          uid: item['uid'],
          transaction_import_id: meta['transaction_import_id']
        )
        meta['created_count'] = (meta['created_count'] || 0) + (tx.persisted? ? 1 : 0)
      end
    else
      # ignore duplicate
      meta['skipped_count'] = (meta['skipped_count'] || 0) + 1
    end

    # remove the processed item
    duplicates = duplicates.reject { |d| d['uid'].to_s == uid }

    # persist back to cache or session depending on where it came from
    if session[:import_duplicates_key].present?
      Rails.cache.write(session[:import_duplicates_key], duplicates, expires_in: 1.hour)
    else
      session[:import_duplicates] = duplicates
    end

    session[:import_meta] = meta

    render json: { remaining: duplicates.length, meta: meta }
  end

  # POST /imports/finish_import
  def finish_import
    meta = session.delete(:import_meta) || {}
    # clear cached duplicates if present
    if session[:import_duplicates_key].present?
      Rails.cache.delete(session.delete(:import_duplicates_key))
    else
      session.delete(:import_duplicates)
    end
    # persist TransactionImport record
    begin
      if meta['transaction_import_id']
        tx_import = TransactionImport.find_by(id: meta['transaction_import_id'])
        if tx_import
          tx_import.update!(created_count: meta['created_count'] || 0, skipped_count: meta['skipped_count'] || 0)
        else
          TransactionImport.create!(account_name: meta['account_name'], filename: meta['filename'], created_count: meta['created_count'] || 0, skipped_count: meta['skipped_count'] || 0)
        end
      else
        TransactionImport.create!(account_name: meta['account_name'], filename: meta['filename'], created_count: meta['created_count'] || 0, skipped_count: meta['skipped_count'] || 0)
      end
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
