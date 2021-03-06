class Admin::ProductsController < Admin::BaseController

  index_attributes [:name, :enabled, :price_str]
  actions [:index, :show, :edit, :new, :delete, :clone]

  # def autocomplete
  #   @products = Product.enabled.where("products.name like ?", "%#{params[:name]}%").limit(10)
  #   respond_to do |format|
  #     format.json { render json: @products.map { |product| product.as_json(:only => :id, :methods => :name) } }
  #   end
  # end
  def index
    cat_id=params[:category] || session[:admin_current_category]
    if cat_id && cat_id!=''
      @category=Category.find(cat_id)
      session[:admin_current_category]=cat_id
      @products = Product.in_categories(@category.all_sub_cats)
    else
      session[:admin_current_category]=nil
      @products=Product.all
    end

    @name_filter=params[:name_filter]
    if @name_filter
      @products=@products.where('lower(products.name) like ?', "%#{@name_filter.downcase}%")      
    end

    @products=@products.rank(:sort_order).page(params[:page]).per(50)

    @categories=Category.all
    respond_with @products
  end

  def copy
    prod=Product.find(params[:id])
    prod_copy=prod.amoeba_dup
    prod_copy.save
    redirect_to [:admin, controller_name]
  end

  private

  def permitted_params
    params.require(:product).permit(:name, :description, :sku, :price, :count, :enabled, :sort_order_position, :external_id, :seo_attributes=>[:title, :description, :keywords], :images_attributes=>[:image, :_destroy, :id], :category_ids=>[], :linked_category_ids=>[], :linked_product_ids=>[], variants_attributes: [:id, :sku, :enabled, :name, :price, :count, :availability, :_destroy], attrs_attributes:[:id, :name, :value, :variantable, :_destroy])
  end
end
