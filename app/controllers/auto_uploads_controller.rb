# frozen_string_literal: true

class AutoUploadsController < ApplicationController
  def index
    @folder_path = ENV['AUTO_FOLDER_UPLOAD_PATH'] || Setting.find_by(key: 'auto_upload_folder_path')&.value || ''
    @histories = AutoUploadHistory.order(uploaded_at: :desc).limit(50)
  end

  def update_folder
    folder_path = params[:folder_path]
    if folder_path.present? && Dir.exist?(folder_path)
      Setting.find_or_create_by(key: 'auto_upload_folder_path').update(value: folder_path)
      flash[:notice] = 'Auto upload folder updated successfully.'
    else
      flash[:alert] = 'Invalid folder path or folder does not exist.'
    end
    redirect_to auto_uploads_path
  end
end
