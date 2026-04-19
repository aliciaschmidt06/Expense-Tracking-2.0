class ImportService
  def self.process_csv(file_path, account_name)
    unknown_category = Category.find_or_create_by!(name: "Unknown")
    categories = Category.all.to_a

    created_count = 0
    skipped_count = 0
    sequence = 0

    # Create an import/session record we can tag transactions with
    begin
      tx_import = TransactionImport.create!(account_name: account_name, filename: File.basename(file_path), created_count: 0, skipped_count: 0)
    rescue => e
      Rails.logger.warn("Failed to create TransactionImport at start of import: #{e.message}")
      tx_import = nil
    end

    CSV.foreach(file_path).with_index(1) do |row, row_number|
      date, description, expense, income, _card = row
      amount_raw = expense.presence || income.presence
      next unless amount_raw

      # Normalize fields
      amount_value = amount_raw.to_f
      transaction_type = expense.present? ? "expense" : "income"
      parsed_date = begin
        DateTime.parse(date.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      category =
        categories.find { |cat| cat.keyword_list.any? { |k| description.to_s.downcase.include?(k.downcase) } } ||
        unknown_category

      # Compute content UID (based on date, name, amounts) used for cross-session duplicate detection
      date_part = parsed_date ? parsed_date.to_date : Time.current.to_date
      amount_out = transaction_type == "expense" ? amount_value : 0
      amount_in = transaction_type == "income" ? amount_value : 0
      content_uid = Transaction.generate_uid(name: description, date: date_part, amount_out: amount_out, amount_in: amount_in)

      # If another session (import) for the same account already contains this content, skip it
      if Transaction.where(content_uid: content_uid, account_name: account_name).where.not(transaction_import_id: tx_import&.id).exists?
        Rails.logger.warn({ event: "import_skip_cross_session_duplicate", row: row_number, uid: content_uid, account: account_name, name: description.to_s }.to_json)
        skipped_count += 1
        next
      end

      # Create a stored UID unique in the DB by including the import id and a sequence number
      created = false
      attempt = 0
      while !created && attempt < 5
        attempt += 1
        sequence += 1
        stored_uid = "#{content_uid}-i#{tx_import&.id || 'local'}-s#{sequence}"
        begin
          Transaction.create!(
            name: description,
            amount: amount_value,
            transaction_type: transaction_type,
            account_name: account_name,
            category: category,
            created_at: parsed_date,
            uid: stored_uid,
            content_uid: content_uid,
            transaction_import_id: tx_import&.id,
            import_sequence: sequence
          )
          created = true
          created_count += 1
        rescue ActiveRecord::RecordInvalid => e
          # Collision on generated stored UID (very unlikely) — retry with next sequence
          if e.message =~ /Uid has already been taken/i
            Rails.logger.warn("UID collision creating stored_uid=#{stored_uid}, retrying (attempt=#{attempt})")
            next
          else
            raise
          end
        end
      end

      unless created
        Rails.logger.warn({ event: "import_failed_create", row: row_number, uid: content_uid }.to_json)
        skipped_count += 1
      end
    end

    # Update the import record
    begin
      if tx_import
        tx_import.update!(created_count: created_count, skipped_count: skipped_count)
      else
        TransactionImport.create!(account_name: account_name, filename: File.basename(file_path), created_count: created_count, skipped_count: skipped_count)
      end
    rescue => e
      Rails.logger.warn "Failed to persist TransactionImport record: #{e.message}"
    end

    { created: created_count, skipped: skipped_count }
  end
end