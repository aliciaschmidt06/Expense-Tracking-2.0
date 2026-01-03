class AddDisplayToTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :transactions, :display, :boolean, default:true, null:false
  end
end
