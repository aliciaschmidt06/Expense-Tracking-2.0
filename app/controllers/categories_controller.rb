class CategoriesController < ApplicationController
  before_action :set_category, only: %i[ show edit update destroy ]

  # GET /categories or /categories.json
  def index
    @categories = Category.all

    # For new hierarchical structure, calculate total spending percentages
    @spending_categories = @categories.where(category_type: 'spending')
    @total_spending_percentage = @spending_categories.sum(:allocation_percentage).to_f
    @percentages_ok = (@total_spending_percentage - 100.0).abs < 0.01

    respond_to do |format|
      format.html
      format.json { render json: @categories }
    end
  end

  # GET /categories/pie_chart_data.json
  # Returns spending categories formatted for pie chart
  def pie_chart_data
    spending_categories = Category.where(category_type: 'spending').order(:subcategory)
    
    data = spending_categories.map do |c|
      {
        id: c.id,
        name: c.name,
        subcategory: c.subcategory,
        percentage: c.allocation_percentage || 0.0,
        target_comparison: c.target_comparison,
        keywords: c.keyword_list
      }
    end

    total_percentage = data.sum { |d| d[:percentage] }

    render json: {
      categories: data,
      total_percentage: total_percentage.round(2),
      percentages_ok: (total_percentage - 100.0).abs < 0.01
    }
  end

  # PATCH /categories/update_percentages.json
  # Updates allocation percentages for spending categories
  def update_percentages
    if params[:categories].blank?
      return render json: { error: "No categories provided" }, status: :unprocessable_entity
    end

    begin
      params[:categories].each do |cat_data|
        category = Category.find(cat_data[:id])
        category.update!(
          name: cat_data[:name],
          allocation_percentage: cat_data[:percentage].to_f,
          target_comparison: cat_data[:target_comparison]
        )
      end

      render json: { success: true, message: "Percentages updated successfully" }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Category not found" }, status: :not_found
    rescue StandardError => e
      Rails.logger.error("Error updating percentages: #{e.message}")
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  # GET /categories/1 or /categories/1.json
  def show
  end

  # GET /categories/new
  def new
    @category = Category.new
  end

  # GET /categories/1/edit
  def edit
  end

  # POST /categories or /categories.json
  def create
    @category = Category.new(category_params)

    respond_to do |format|
      if @category.save
        format.html { redirect_to @category, notice: "Category was successfully created." }
        format.json { render :show, status: :created, location: @category }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @category.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /categories/1 or /categories/1.json
  def update
    respond_to do |format|
      if @category.update(category_params)
        format.html { redirect_to @category, notice: "Category was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @category }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @category.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /categories/1 or /categories/1.json
  def destroy
    @category.destroy!

    respond_to do |format|
      format.html { redirect_to categories_path, notice: "Category was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  # GET /categories/download_yaml
  # Exports current categories as a YAML file with hierarchical structure
  def download_yaml
    categories = Category.all

    data = {}

    # Group categories by type
    income_cats = categories.where(category_type: 'income')
    spending_cats = categories.where(category_type: 'spending')

    # Export Income section
    if income_cats.any?
      # Combine all income keywords into a single array
      all_income_keywords = income_cats.flat_map(&:keyword_list).uniq
      data["income"] = { "keywords" => all_income_keywords }
    end

    # Export Spending section
    if spending_cats.any?
      spending_data = {}
      spending_cats.each do |c|
        subcategory = c.subcategory || c.name.downcase
        spending_data[subcategory] = c.keyword_list
      end
      data["spending_categories"] = spending_data
    end

    yaml = YAML.dump(data).sub(/\A---\n/, '')
    header = "# Expense Tracking Configuration\n# Export from Expense-Tracking-2.0\n# Percentages are auto-calculated to be equal, adjust in the pie chart\n\n"

    send_data(header + yaml, filename: "categories.yaml", type: "text/yaml")
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_category
      @category = Category.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    # The form submits `keywords` as a plain text field (comma-separated),
    # so permit it as a scalar. The model's `keyword_list` handles parsing.
    def category_params
      params.require(:category).permit(:name, :target_percentage, :keywords, :target_comparison, :category_type, :subcategory, :allocation_percentage)
    end
end
