# frozen_string_literal: true

require 'listen'

class AutoUploadService
  def self.start_monitoring(folder_path)
    return unless Dir.exist?(folder_path)

    listener = Listen.to(folder_path) do |_modified, added, _removed|
      added.each do |file_path|
        next unless File.extname(file_path).downcase == '.csv'

        process_file(file_path)
      end
    end

    listener.start
    Rails.logger.info "Auto upload monitoring started for #{folder_path}"
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

    begin
      result = ImportService.process_csv(file_path, account_name)
      history.update!(status: 'completed')
      Rails.logger.info "Auto uploaded #{file_path}: #{result[:created]} created, #{result[:skipped]} skipped"
    rescue StandardError => e
      history.update!(status: 'failed', error_message: e.message)
      Rails.logger.error "Auto upload failed for #{file_path}: #{e.message}"
    end
  end
end
