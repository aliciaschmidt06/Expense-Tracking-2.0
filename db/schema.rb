# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_19_184850) do
  create_table "auto_upload_histories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "file_name"
    t.string "file_path"
    t.string "status"
    t.datetime "updated_at", null: false
    t.datetime "uploaded_at"
  end

  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "keywords"
    t.string "name"
    t.string "target_comparison"
    t.float "target_percentage"
    t.datetime "updated_at", null: false
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key"
    t.datetime "updated_at", null: false
    t.string "value"
  end

  create_table "transaction_imports", force: :cascade do |t|
    t.string "account_name", null: false
    t.datetime "created_at", null: false
    t.integer "created_count", default: 0, null: false
    t.string "filename"
    t.integer "skipped_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["account_name"], name: "index_transaction_imports_on_account_name"
  end

  create_table "transactions", force: :cascade do |t|
    t.string "account_name"
    t.float "amount"
    t.integer "category_id", null: false
    t.string "content_uid"
    t.datetime "created_at", null: false
    t.boolean "display", default: true, null: false
    t.integer "import_sequence"
    t.string "name"
    t.boolean "to_be_reimbursed", default: false
    t.integer "transaction_import_id"
    t.integer "transaction_type", default: 0, null: false
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["content_uid", "account_name"], name: "index_transactions_on_content_uid_and_account"
    t.index ["import_sequence"], name: "index_transactions_on_import_sequence"
    t.index ["transaction_import_id"], name: "index_transactions_on_transaction_import_id"
    t.index ["uid"], name: "index_transactions_on_uid", unique: true
  end

  add_foreign_key "transactions", "categories"
end
