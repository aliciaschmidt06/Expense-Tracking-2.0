class TransactionImport < ApplicationRecord
  validates :account_name, presence: true

  def display_name
    [account_name, filename.presence].compact.join(' — ')
  end
end
