class Category < ApplicationRecord
  has_many :transactions

  # Comparison rule for target percentage. Stored as string in :target_comparison.
  # Use the constant and simple helpers instead of ActiveRecord::Enum to avoid
  # compatibility issues across Rails versions.
  TARGET_COMPARISONS = %w[equal_to less_than greater_than not_applicable].freeze

  validates :target_comparison, inclusion: { in: TARGET_COMPARISONS }, allow_nil: true

  def target_comparison_human
    target_comparison.to_s.humanize unless target_comparison.blank?
  end

  def less_than?
    target_comparison == 'less_than'
  end

  def greater_than?
    target_comparison == 'greater_than'
  end

  def equal_to?
    target_comparison == 'equal_to'
  end

  def not_applicable?
    target_comparison == 'not_applicable'
  end

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

  # After any save, try to assign transactions whose names match this
  # category's keywords to this category. This keeps transactions up-to-date
  # when new categories are created or imported.
  after_save :assign_transactions_by_keywords
  # Before destroying a category, try to reassign its transactions to the best
  # matching remaining category, otherwise fall back to the 'Unknown' category.
  before_destroy :reassign_transactions_on_destroy

  private

  def update_display_for_ignore
    return if keyword_list.empty?

    keyword_list.each do |keyword|
      Transaction
        .where("LOWER(name) LIKE ?", "%#{keyword.downcase}%")
        .update_all(display: false)
    end
  end

  def assign_transactions_by_keywords
    return if keyword_list.empty?

    # For each keyword, assign matching transactions to this category.
    # Use update_all for efficiency; skip transactions already assigned to this category.
    keyword_list.each do |keyword|
      next if keyword.blank?

      term = "%#{keyword.downcase}%"
      Transaction.where("LOWER(name) LIKE ?", term)
                 .where.not(category_id: id)
                 .update_all(category_id: id)
    end
  end

  def reassign_transactions_on_destroy
    # Capture remaining categories (exclude self) for matching
    remaining = Category.where.not(id: id).to_a

    # Ensure there's an 'Unknown' fallback category
    unknown = Category.find_or_create_by!(name: "Unknown")

    Transaction.where(category_id: id).find_each do |tx|
      # find the first remaining category whose keywords match the transaction name
      matched = remaining.detect do |c|
        c.keyword_list.any? do |kw|
          kw.present? && tx.name.to_s.downcase.include?(kw.downcase)
        end
      end

      if matched
        # update without running callbacks for speed; set display false if matched is Ignore
        attrs = { category_id: matched.id }
        attrs[:display] = false if matched.name.to_s.downcase == "ignore"
        tx.update_columns(attrs)
      else
        # No match found — assign to Unknown
        tx.update_columns(category_id: unknown.id)
      end
    end
  end
end
