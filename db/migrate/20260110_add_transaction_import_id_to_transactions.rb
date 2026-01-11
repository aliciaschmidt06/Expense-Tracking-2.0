class AddTransactionImportIdToTransactions < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:transactions, :transaction_import_id)
      add_column :transactions, :transaction_import_id, :integer
    end

    unless index_exists?(:transactions, :transaction_import_id)
      add_index :transactions, :transaction_import_id
    end
  end
end
class AddTransactionImportIdToTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :transactions, :transaction_import_id, :integer
    add_index :transactions, :transaction_import_id
  end
end
