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

    CSV.foreach(file.path) do |row|
      date, description, expense, income, _card = row
      amount = expense.presence || income.presence
      next unless amount

      transaction_type = expense.present? ? "expense" : "income"
      category =
        categories.find { |cat| cat.keyword_list.any? { |k| description.to_s.downcase.include?(k.downcase) } } ||
        unknown_category

      Transaction.create!(
        name: description,
        amount: amount,
        transaction_type: transaction_type,
        account_name: account_name,
        category: category,
        created_at: date
      )
    end

    redirect_to transactions_path, notice: "Transactions imported successfully"
  end
end
