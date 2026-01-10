json.extract! category, :id, :name, :target_percentage, :keywords, :created_at, :updated_at
json.target_comparison category.target_comparison
json.url category_url(category, format: :json)
