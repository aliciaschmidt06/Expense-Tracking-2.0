# app/controllers/imports_controller.rb
require "csv"

class ImportsController < ApplicationController
  def new; end

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

      # Skip if a transaction with same UID already exists
      if Transaction.exists?(uid: uid)
        skipped_count += 1
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

    # Build notice message with counts
    notice_msg = "Transactions imported successfully"
    details = []
    details << "#{created_count} #{created_count == 1 ? 'new record' : 'new records'}" if created_count > 0
    details << "#{skipped_count} #{skipped_count == 1 ? 'duplicate skipped' : 'duplicates skipped'}" if skipped_count > 0
    notice_msg += " — " + details.join(', ') unless details.empty?

    redirect_to transactions_path, notice: notice_msg
  end
end
