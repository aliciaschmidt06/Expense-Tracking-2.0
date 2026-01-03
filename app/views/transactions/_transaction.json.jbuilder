json.extract! transaction, :id, :name, :amount, :transaction_type, :account_name, :category_id, :to_be_reimbursed, :created_at, :updated_at
json.url transaction_url(transaction, format: :json)
