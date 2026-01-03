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

      if yaml_data["categories"].present?
        yaml_data["categories"].each do |name, details|
          category = Category.find_or_initialize_by(name: name)
          category.keywords = details["keywords"] || []
          category.target_percentage = details["target_percentage"] || 0
          category.save!
        end
      end

      redirect_to categories_path, notice: "Categories imported successfully"

    rescue Psych::SyntaxError => e
      redirect_to new_category_import_path, alert: "Invalid YAML file: #{e.message}"
    rescue ActiveRecord::RecordInvalid => e
      redirect_to new_category_import_path, alert: "Failed to save category '#{e.record.name}': #{e.record.errors.full_messages.join(', ')}"
    end
  end
end
