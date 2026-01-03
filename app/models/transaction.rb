class Transaction < ApplicationRecord
  belongs_to :category


  enum :transaction_type, { expense: 0, income: 1 }, prefix: true

  # UID for deduplication
  before_validation :set_uid, on: :create
  validates :uid, presence: true, uniqueness: true

  after_initialize :set_default_category, if: :new_record?
  after_initialize :set_display, if: :new_record?

  private

  def set_uid
    return if uid.present?
    self.uid = self.class.generate_uid(name: name, amount: amount, datetime: created_at || Time.current)
  end

  def self.generate_uid(name:, amount:, datetime:)
    require "digest"
    normalized_name = name.to_s.strip.downcase
    normalized_amount = (amount || 0).to_f.round(2).to_s
    normalized_time = (datetime || Time.current).to_s
    Digest::SHA256.hexdigest([normalized_time, normalized_amount, normalized_name].join("-"))[0,20]
  end

  def set_default_category
    self.category ||= Category.find_or_create_by!(name: "Unknown")
  end

  def set_display
    # Hide transactions automatically if category is Ignore
    self.display = false if category&.name == "Ignore"
  end
end
