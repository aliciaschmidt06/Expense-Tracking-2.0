class AddTargetComparisonToCategories < ActiveRecord::Migration[7.0]
  def change
    add_column :categories, :target_comparison, :string
  end
end
