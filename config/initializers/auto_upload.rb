puts "=" * 60
puts "AUTO UPLOAD INITIALIZER LOADING..."
puts "=" * 60

# Load .env file if it exists
env_file = Rails.root.join('.env')
if File.exist?(env_file)
  puts "[AUTO UPLOAD] Loading .env file: #{env_file}"
  require 'dotenv'
  Dotenv.load(env_file)
end

Rails.application.config.after_initialize do
  puts "[AUTO UPLOAD] after_initialize hook running"
  puts "[AUTO UPLOAD] Environment: #{Rails.env}"
  
  if Rails.env.development? || Rails.env.production?
    puts "[AUTO UPLOAD] Checking for folder configuration..."
    
    # Try multiple sources for the folder path
    folder_path = ENV['AUTO_FOLDER_UPLOAD_PATH']
    puts "[AUTO UPLOAD] ENV['AUTO_FOLDER_UPLOAD_PATH']: #{folder_path.inspect}"
    
    # If not in ENV, try the database settings
    folder_path ||= Setting.find_by(key: 'auto_upload_folder_path')&.value
    puts "[AUTO UPLOAD] Database setting: #{folder_path.inspect}" if folder_path
    
    puts "[AUTO UPLOAD] Final folder path: #{folder_path.inspect}"
    
    if folder_path.present?
      folder_exists = Dir.exist?(folder_path)
      puts "[AUTO UPLOAD] Folder exists: #{folder_exists}"
      
      if folder_exists
        puts "[AUTO UPLOAD] Starting monitoring service..."
        Rails.logger.info "🟢 AUTO UPLOAD INITIALIZING: #{folder_path}"
        AutoUploadService.start_monitoring(folder_path)
        puts "[AUTO UPLOAD] ✅ Monitoring started!"
      else
        puts "[AUTO UPLOAD] ❌ Folder does not exist: #{folder_path}"
        Rails.logger.warn "🔴 AUTO UPLOAD DISABLED: Folder does not exist: #{folder_path}"
      end
    else
      puts "[AUTO UPLOAD] ❌ No folder path configured"
      Rails.logger.warn "🔴 AUTO UPLOAD DISABLED: No folder path configured"
    end
  else
    puts "[AUTO UPLOAD] ⏭️  Skipping (not development or production)"
  end
  
  puts "[AUTO UPLOAD] Initialization complete"
  puts "=" * 60
end