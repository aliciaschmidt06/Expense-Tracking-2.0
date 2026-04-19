class RefactorCategoriesForHierarchicalStructure < ActiveRecord::Migration[8.1]
  def change
    # Add new fields to support hierarchical category structure
    add_column :categories, :category_type, :string, default: "spending"
    add_column :categories, :subcategory, :string
    add_column :categories, :allocation_percentage, :float, default: 0.0
    add_column :categories, :config_yaml_structure, :text  # Store the full hierarchy as JSON

    # Add index for faster lookups by type and subcategory
    add_index :categories, [:category_type, :subcategory]
  end
end
