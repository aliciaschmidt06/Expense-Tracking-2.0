class AddContentUidAndImportSequenceToTransactions < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:transactions, :content_uid)
      add_column :transactions, :content_uid, :string
    end

    unless column_exists?(:transactions, :import_sequence)
      add_column :transactions, :import_sequence, :integer
    end

    unless index_exists?(:transactions, [:content_uid, :account_name], name: "index_transactions_on_content_uid_and_account")
      add_index :transactions, [:content_uid, :account_name], name: "index_transactions_on_content_uid_and_account"
    end

    unless index_exists?(:transactions, :import_sequence)
      add_index :transactions, :import_sequence
    end
  end
end
