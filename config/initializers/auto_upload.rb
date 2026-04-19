Rails.application.config.after_initialize do
  if Rails.env.development? || Rails.env.production?
    folder_path = ENV['AUTO_FOLDER_UPLOAD_PATH'] || Setting.find_by(key: 'auto_upload_folder_path')&.value
    if folder_path.present?
      AutoUploadService.start_monitoring(folder_path)
    end
  end
end