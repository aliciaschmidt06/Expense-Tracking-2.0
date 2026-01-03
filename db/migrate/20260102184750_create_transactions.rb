class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :transactions do |t|
      t.string :name
      t.float :amount
      t.integer :transaction_type, null: false, default: 0
      t.string :account_name
      t.references :category, null: false, foreign_key: true
      t.boolean :to_be_reimbursed, default: false

      t.timestamps
    end
  end
end
