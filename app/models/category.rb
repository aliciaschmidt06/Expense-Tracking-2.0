class Category < ApplicationRecord
  has_many :transactions

  # Always return an array
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

  # Callback: update transactions if this is the "ignore" category
  after_save :update_display_for_ignore, if: -> { name.downcase == "ignore" }

  private

  def update_display_for_ignore
    return if keyword_list.empty?

    keyword_list.each do |keyword|
      Transaction
        .where("LOWER(name) LIKE ?", "%#{keyword.downcase}%")
        .update_all(display: false)
    end
  end
end
