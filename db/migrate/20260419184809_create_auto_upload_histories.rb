class CreateAutoUploadHistories < ActiveRecord::Migration[8.1]
  def change
    create_table :auto_upload_histories do |t|
      t.string :file_name
      t.string :file_path
      t.datetime :uploaded_at
      t.string :status
      t.text :error_message

      t.timestamps
    end
  end
end
