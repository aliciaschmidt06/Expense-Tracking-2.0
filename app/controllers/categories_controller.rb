class CategoriesController < ApplicationController
  before_action :set_category, only: %i[ show edit update destroy ]

  # GET /categories or /categories.json
  def index
    @categories = Category.all

    # Compute the total of target percentages for all categories so the view
    # can show a persistent warning if the total isn't 100%.
    @total_percentage = Category.sum(:target_percentage).to_f
    @percentages_ok = (@total_percentage - 100.0).abs < 0.01
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
  # Exports current categories as a YAML file formatted like public/categories.template.yaml
  def download_yaml
    categories = Category.all

    data = { "categories" => {} }
    categories.each do |c|
      key = c.name.to_s.parameterize(separator: '-')
      details = {}
      keywords = c.keyword_list
      # include keywords key only if present to keep YAML tidy
      details["keywords"] = keywords unless keywords.blank?
      details["target_percentage"] = (c.target_percentage || 0)
      data["categories"][key] = details
    end

    yaml = YAML.dump(data).sub(/\A---\n/, '')
    header = "# Exported categories YAML from Expense-Tracking-2.0\n# You can edit and re-upload this file.\n"

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
      params.require(:category).permit(:name, :target_percentage, :keywords)
    end
end
