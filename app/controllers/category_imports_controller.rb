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

      # helper to extract numeric percentage from either a scalar or the new mapping
      extract_pct = lambda do |raw_target|
        case raw_target
        when Hash
          if raw_target["equal_to"]
            raw_target["equal_to"].to_f
          elsif raw_target["less_than"]
            raw_target["less_than"].to_f
          elsif raw_target["greater_than"]
            raw_target["greater_than"].to_f
          else
            0.0
          end
        when Numeric
          raw_target.to_f
        when String
          raw_target.to_s.match?(/\A[+-]?\d+(?:\.\d+)?\z/) ? raw_target.to_f : 0.0
        else
          0.0
        end
      end

      if yaml_data["categories"].present?
        yaml_data["categories"].each do |_name, details|
          next unless details.is_a?(Hash)
          total_percentage += extract_pct.call(details["target_percentage"])
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

          # Support new YAML format where target_percentage may be a scalar or a map
          raw_target = details["target_percentage"]
          case raw_target
          when Hash
            # Expect one of: equal_to, less_than, greater_than or not_applicable
            if raw_target["equal_to"]
              category.target_percentage = raw_target["equal_to"].to_f
              category.target_comparison = "equal_to"
            elsif raw_target["less_than"]
              category.target_percentage = raw_target["less_than"].to_f
              category.target_comparison = "less_than"
            elsif raw_target["greater_than"]
              category.target_percentage = raw_target["greater_than"].to_f
              category.target_comparison = "greater_than"
            elsif raw_target["not_applicable"]
              category.target_percentage = nil
              category.target_comparison = "not_applicable"
            else
              # unknown structure: fallback to numeric 0
              category.target_percentage = 0
              category.target_comparison = "equal_to"
            end
          when Numeric
            category.target_percentage = raw_target.to_f
            category.target_comparison = "equal_to"
          when String
            # try parse as numeric
            if raw_target.to_s.match?(/\A[+-]?\d+(?:\.\d+)?\z/)
              category.target_percentage = raw_target.to_f
              category.target_comparison = "equal_to"
            else
              category.target_percentage = 0
              category.target_comparison = "equal_to"
            end
          else
            category.target_percentage = details["target_percentage"] || 0
            category.target_comparison = "equal_to"
          end
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
