# app/controllers/category_imports_controller.rb
require "yaml"

class CategoryImportsController < ApplicationController
  def new
  end

  def create
    config_file = params[:config]

    unless config_file.present?
      redirect_to new_category_import_path, alert: "Please upload a YAML file" and return
    end

    begin
      yaml_data = YAML.safe_load(config_file.read)

      # Clear existing categories for fresh import
      Category.delete_all

      # Helper to extract keywords from various formats
      extract_keywords = lambda do |raw_keywords|
        case raw_keywords
        when Array
          raw_keywords.map(&:to_s)
        when String
          [raw_keywords]
        else
          []
        end
      end

      # Process Income categories
      if yaml_data["income"].present?
        income_data = yaml_data["income"]
        if income_data["keywords"].is_a?(Array)
          category = Category.create!(
            name: "Income",
            category_type: "income",
            keywords: income_data["keywords"].map(&:to_s)
          )
        end
      end

      # Process Spending categories and their subcategories
      if yaml_data["spending_categories"].present? && yaml_data["spending_categories"].is_a?(Hash)
        spending_data = yaml_data["spending_categories"]
        
        # Count spending categories to calculate equal percentages
        spending_count = spending_data.size
        equal_percentage = spending_count > 0 ? (100.0 / spending_count) : 0.0

        # Create categories for each spending subcategory
        spending_data.each do |subcategory_name, items_raw|
          # Handle both array and hash formats
          keywords = case items_raw
                     when Array
                       items_raw.map(&:to_s)
                     when Hash
                       # Support backward compatibility with items/keywords keys
                       items = items_raw["keywords"] || items_raw["items"]
                       Array(items).map(&:to_s)
                     else
                       []
                     end

          category = Category.create!(
            name: subcategory_name.to_s.titleize,
            category_type: "spending",
            subcategory: subcategory_name.to_s,
            keywords: keywords,
            allocation_percentage: equal_percentage
          )
        end
      end

      redirect_to categories_path, notice: "Categories imported successfully"

    rescue Psych::SyntaxError => e
      Rails.logger.error("Category import YAML syntax error: #{e.message}")
      redirect_to new_category_import_path, alert: "Invalid YAML file: #{e.message}"
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Category import failed saving: #{e.record.inspect} #{e.record.errors.full_messages.join(', ')}")
      redirect_to new_category_import_path,
                  alert: "Failed to save category '#{e.record.name}': #{e.record.errors.full_messages.join(', ')}"
    rescue StandardError => e
      Rails.logger.error("Category import unexpected error: #{e.class} #{e.message}\n#{e.backtrace.join("\n")}")
      redirect_to new_category_import_path, alert: "Import failed: #{e.message}"
    end
  end

  private

  def extract_percentage(raw_percentage)
    case raw_percentage
    when Numeric
      raw_percentage.to_f
    when String
      raw_percentage.to_s.match?(/\A[+-]?\d+(?:\.\d+)?\z/) ? raw_percentage.to_f : 0.0
    else
      0.0
    end
  end
end
