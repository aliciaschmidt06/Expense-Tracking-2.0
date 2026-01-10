class SettingsController < ApplicationController
  def index
    # show settings page; messages are provided via flash
  end

  def clear_transactions
    Transaction.delete_all
    flash[:notice] = 'All transactions have been deleted.'
    redirect_to settings_path
  end

  def clear_categories
    # Reassign any transactions to an 'Unknown' fallback category before removing categories
    unknown = Category.find_or_create_by!(name: 'Unknown')
    Transaction.where.not(category_id: unknown.id).update_all(category_id: unknown.id)

    # Remove all categories except the Unknown fallback
    Category.where.not(id: unknown.id).delete_all

    flash[:notice] = "All categories have been cleared. Transactions were reassigned to '#{unknown.name}'."
    redirect_to settings_path
  end
end
