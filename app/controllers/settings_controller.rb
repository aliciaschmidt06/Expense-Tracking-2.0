class SettingsController < ApplicationController
  def index
    # show settings page; messages are provided via flash
  end

  def clear_transactions
    Transaction.delete_all

    # Also remove any persisted upload history so the Upload page reflects
    # the fact there are no transactions. This prevents confusing UI where
    # old import records reappear after a fresh upload.
    begin
      TransactionImport.delete_all
    rescue => e
      Rails.logger.warn "Failed to clear TransactionImport records: #{e.message}"
    end

    # Clear any in-progress import session/cache state
    if session[:import_duplicates_key].present?
      Rails.cache.delete(session.delete(:import_duplicates_key))
    end
    session.delete(:import_duplicates)
    session.delete(:import_meta)

    flash[:notice] = 'All transactions and upload history have been deleted.'
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
