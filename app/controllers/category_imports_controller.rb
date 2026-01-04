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

      total_percentage = 0.0

      if yaml_data["categories"].present?
        yaml_data["categories"].each do |_name, details|
          next unless details.is_a?(Hash)
          total_percentage += (details["target_percentage"] || 0).to_f
        end
      end

      flash[:import_total] = total_percentage
      flash[:import_total_ok] = (total_percentage <= 100.0)

      if yaml_data["categories"].present?
        yaml_data["categories"].each do |name, details|
          next unless details.is_a?(Hash)

          category = Category.find_or_initialize_by(name: name)

          raw_keywords = details["keywords"]
          category.keywords =
            case raw_keywords
            when Array
              raw_keywords.map(&:to_s)
            when String
              [raw_keywords]
            else
              []
            end

          category.target_percentage = details["target_percentage"] || 0
          category.save!
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
end
