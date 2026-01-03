# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# db/seeds.rb
ignore_category = Category.find_or_create_by!(name: "Ignore") do |cat|
  cat.keywords = ["ignore"]
  cat.target_percentage = nil
end

# Ensure keywords is an array if the record already existed
ignore_category.keywords = ["ignore"] unless ignore_category.keywords.is_a?(Array)
ignore_category.save!
