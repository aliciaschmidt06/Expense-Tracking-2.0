class CreateTransactionImports < ActiveRecord::Migration[6.1]
  def change
    create_table :transaction_imports do |t|
      t.string :account_name, null: false
      t.string :filename
      t.integer :created_count, default: 0, null: false
      t.integer :skipped_count, default: 0, null: false

      t.timestamps
    end

    add_index :transaction_imports, :account_name
  end
end
