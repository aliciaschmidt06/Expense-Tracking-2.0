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

  # Note: the old manual duplicates review flow (duplicates/resolve_duplicate/finish_import)
  # has been removed. Import now automatically skips cross-session duplicates and
  # allows intra-file duplicates by tagging transactions with a transaction_import_id
  # and per-import import_sequence. If any session/cache keys remain they are harmless
  # but will be ignored by the import flow.
end
