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
    # Build UID from date, name, amount out (expense) and amount in (income)
    date_part = (created_at || Time.current).to_date
    amount_out = transaction_type == "expense" ? amount : 0
    amount_in = transaction_type == "income" ? amount : 0
    self.uid = self.class.generate_uid(name: name, date: date_part, amount_out: amount_out, amount_in: amount_in)
  end

  # Generate a UID from the transaction date, normalized name/description,
  # and separate amounts for out (expense) and in (income). Using the date
  # (not full datetime) helps avoid minor timestamp differences causing new UIDs.
  def self.generate_uid(name:, date:, amount_out:, amount_in:)
    require "digest"
    normalized_name = name.to_s.strip.downcase
    normalized_date = (date || Time.current.to_date).to_s
    normalized_out = (amount_out || 0).to_f.round(2).to_s
    normalized_in = (amount_in || 0).to_f.round(2).to_s
    Digest::SHA256.hexdigest([normalized_date, normalized_name, normalized_out, normalized_in].join("-") )[0,20]
  end

  def set_default_category
    self.category ||= Category.find_or_create_by!(name: "Unknown")
  end

  def set_display
    # Hide transactions automatically if category is Ignore
    self.display = false if category&.name == "Ignore"
  end
end
