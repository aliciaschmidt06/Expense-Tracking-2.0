class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.string :name
      t.float :target_percent, null: true, default: 0
      t.json :keywords, default: []   # <- store keywords as JSON array

      t.timestamps
    end
  end
end
