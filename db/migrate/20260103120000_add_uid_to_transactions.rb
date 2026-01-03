class AddUidToTransactions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    unless column_exists?(:transactions, :uid)
      add_column :transactions, :uid, :string
    end

    say_with_time "Backfilling transaction UIDs" do
      require "digest"
      Transaction.reset_column_information
      Transaction.where(uid: [nil, ""]).find_each do |t|
        datetime = (t.created_at || Time.now).to_s
        base_uid = Digest::SHA256.hexdigest([datetime.to_s, t.amount.to_f.round(2).to_s, t.name.to_s.strip.downcase].join("-"))[0,20]
        uid = base_uid
        suffix = 1
        # ensure uid uniqueness when backfilling existing rows
        while Transaction.where(uid: uid).exists?
          uid = "#{base_uid}-#{suffix}"
          suffix += 1
        end
        t.update_columns(uid: uid)
      end
    end

    # Add index; :concurrently option only supported on some adapters (e.g. Postgres)
    unless index_exists?(:transactions, :uid)
      if ActiveRecord::Base.connection.adapter_name.downcase.include?("postgresql")
        add_index :transactions, :uid, unique: true, algorithm: :concurrently
      else
        add_index :transactions, :uid, unique: true
      end
    end
  end

  def down
    remove_index :transactions, :uid if index_exists?(:transactions, :uid)
    remove_column :transactions, :uid
  end
end
