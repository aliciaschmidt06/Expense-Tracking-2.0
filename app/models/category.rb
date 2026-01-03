class Category < ApplicationRecord
  has_many :transactions

  # Returns an array of keywords, regardless of whether stored as JSON or string
  def keyword_list
    case keywords
    when Array
      keywords
    when String
      JSON.parse(keywords) rescue []
    else
      []
    end
  end

  # Callback: update transactions if this is the "Ignore" category
  after_save :update_display_for_ignore, if: -> { name.downcase == "ignore" }

  private

  def update_display_for_ignore
    return unless keywords.present?

    # Mark existing transactions as display: false if their description matches any ignore keyword
    keywords.each do |keyword|
      Transaction.where("LOWER(description) LIKE ?", "%#{keyword.downcase}%")
                 .update_all(display: false)
    end
  end
end
