# frozen_string_literal: true

require 'listen'

class AutoUploadService
  def self.start_monitoring(folder_path)
    return unless Dir.exist?(folder_path)

    Rails.logger.info "=========================================="
    Rails.logger.info "🚀 Auto upload service starting"
    Rails.logger.info "📁 Monitoring folder: #{folder_path}"
    Rails.logger.info "=========================================="

    listener = Listen.to(folder_path) do |_modified, added, _removed|
      if added.any?
        Rails.logger.info "📥 Detected #{added.count} file(s) in upload folder"
      end
      
      added.each do |file_path|
        Rails.logger.info "📄 Processing file: #{file_path}"
        
        unless File.extname(file_path).downcase == '.csv'
          Rails.logger.warn "⚠️  Skipping non-CSV file: #{File.basename(file_path)}"
          next
        end

        Rails.logger.info "✅ CSV file detected, starting import..."
        process_file(file_path)
      end
    end

    listener.start
    Rails.logger.info "✔️  Auto upload monitoring is now active"
    listener
  end

  def self.process_file(file_path) # rubocop:disable Metrics/MethodLength
    account_name = 'Auto Upload' # Default account name, could be configurable

    history = AutoUploadHistory.create!(
      file_name: File.basename(file_path),
      file_path: file_path,
      uploaded_at: Time.current,
      status: 'processing'
    )

    Rails.logger.info "🔄 Created upload record: #{history.id}"
    Rails.logger.info "📊 Processing CSV: #{File.basename(file_path)}"

    begin
      result = ImportService.process_csv(file_path, account_name)
      history.update!(status: 'completed')
      
      Rails.logger.info "✅ AUTO UPLOAD COMPLETED"
      Rails.logger.info "   Created: #{result[:created]} transactions"
      Rails.logger.info "   Skipped: #{result[:skipped]} transactions"
      Rails.logger.info "   File: #{File.basename(file_path)}"
      Rails.logger.info "=========================================="
    rescue StandardError => e
      history.update!(status: 'failed', error_message: e.message)
      
      Rails.logger.error "❌ AUTO UPLOAD FAILED"
      Rails.logger.error "   File: #{File.basename(file_path)}"
      Rails.logger.error "   Error: #{e.message}"
      Rails.logger.error "   Backtrace: #{e.backtrace.first(5).join("\n   ")}"
      Rails.logger.error "=========================================="
    end
  end
end
