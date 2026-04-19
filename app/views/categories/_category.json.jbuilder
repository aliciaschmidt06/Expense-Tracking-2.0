json.extract! category, :id, :name, :target_percentage, :keywords, :category_type, :subcategory, :allocation_percentage, :created_at, :updated_at
json.target_comparison category.target_comparison
json.is_ignored category.is_ignored?
json.url category_url(category, format: :json)
