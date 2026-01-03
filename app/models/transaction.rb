class Transaction < ApplicationRecord
  belongs_to :category

  enum :transaction_type, { expense: 0, income: 1 }, prefix: true

  after_initialize :set_default_category, if: :new_record?
  after_initialize :set_display, if: :new_record?

  private

  def set_default_category
    self.category ||= Category.find_or_create_by!(name: "Unknown")
  end

  def set_display
    # Hide transactions automatically if category is Ignore
    self.display = false if category&.name == "Ignore"
  end
end
