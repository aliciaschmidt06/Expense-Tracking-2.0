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

ActiveRecord::Schema[8.1].define(version: 2026_01_03_120000) do
  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "keywords"
    t.string "name"
    t.float "target_percentage"
    t.datetime "updated_at", null: false
  end

  create_table "transactions", force: :cascade do |t|
    t.string "account_name"
    t.float "amount"
    t.integer "category_id", null: false
    t.datetime "created_at", null: false
    t.boolean "display", default: true, null: false
    t.string "name"
    t.boolean "to_be_reimbursed", default: false
    t.integer "transaction_type", default: 0, null: false
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["uid"], name: "index_transactions_on_uid", unique: true
  end

  add_foreign_key "transactions", "categories"
end
