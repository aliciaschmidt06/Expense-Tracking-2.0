class Category < ApplicationRecord
  has_many :transactions

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
end
