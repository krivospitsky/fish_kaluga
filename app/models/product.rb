#coding:utf-8

include ProductsHelper

class Product < ActiveRecord::Base
  has_many :images, :dependent => :destroy
  accepts_nested_attributes_for :images, allow_destroy:true

  has_many :attrs, :dependent => :destroy
  accepts_nested_attributes_for :attrs, allow_destroy:true

  has_many :variants, :dependent => :destroy
  accepts_nested_attributes_for :variants, allow_destroy:true


  has_many :variant_attrs, -> {where :'variants.enabled' => true}, through: :variants, source: :attrs

  has_and_belongs_to_many(:categories,
    :join_table => "categories_products")

  has_and_belongs_to_many(:linked_categories,
    class_name: 'Category',
    :join_table => "products_linked_categories")

  has_and_belongs_to_many(:linked_products,
    class_name: 'Product',
    :join_table => "products_linked_products",
    :association_foreign_key=> 'linked_product_id' )

  include RankedModel
    ranks :sort_order

  include  Seoable

  # serialize :attr, Hash

  amoeba do
    enable
      prepend :name => "КОПИЯ "
      set enabled: false
      exclude_association :images
      # clone [:categories, :linked_categories, :linked_products]
      customize(lambda { |original_item,new_item|
        original_item.images.each{|p| new_item.images.new :image => p.image.file}
      })
  end

  # default_scope -> {order(sort_order: :asc)}
  scope :enabled, -> { where(enabled: 't') }
  #scope :enabled, -> { joins(:variants).where("variants.enabled" => 't') }

  scope :in_categories, ->(cats) {joins(:categories).where('category_id in (?)', cats.map{|a| a.id})}

  def self.search(search)
    enabled.where('lower(name) LIKE lower(:search)', search: "%#{search}%")
  end

  def self.discounted
    Product.enabled.joins(:categories).where('category_id in (?) or products.id in (?)', Discount.current.joins(:categories).pluck(:category_id), Discount.current.joins(:products).pluck(:product_id))
  end

  # def price
  #   prices=variants.map {|v| v.price}
  #   if prices.min == prices.max
  #     return prices[0]
  #   else
  #     return "от #{prices.min} до #{prices.max}"
  #   end
  # end

  def availability
	  # return 'В наличии' if count>0
	  # return 'Под заказ' if count==0
      return 'В наличии'
	end

  def linked
    result=[]

    result += linked_products.enabled

    linked_categories.each do |cat|
      result += cat.products.enabled
    end


    Category.where('id in (?)', categories.flat_map{|c| c.parent_ids}).each do |cat|
      result += cat.linked_products.enabled

      cat.linked_categories.each do |cat|
        result += cat.products.enabled
      end
    end
    result-=[self]
    result.uniq[0..7]
  end

  def get_discount
    max_discount1 = Discount.current.joins(:products).where('products.id = ?', id).maximum(:discount) || 0

    max_discount2 = Discount.current.joins(:categories).where('categories.id in (?)', categories.flat_map{|c| c.parent_ids}).maximum(:discount) || 0
    max_discount = [max_discount1, max_discount2].max

    max_discount

    # #
    # if max_discount>0
    #   return price * (100 - max_discount) / 100
    #   # 
    #   #   return prices[0] * (100 - max_discount) / 100
    #   # else
    #   #   return "от #{prices.min * (100 - max_discount) / 100} до #{prices.max * (100 - max_discount) / 100}"
    #   # end
    # end

    # false
  end

  def price_str
    if variants.count==0
      "по запросу"
    else
      discount=get_discount
      c=1
      if discount && discount>0
        c=(100-discount)/100.0
      end
      if min_price == max_price
        "#{to_price((min_price.to_i*c).to_i)}"
      else
        "#{to_price((min_price.to_i*c).to_i)}&nbsp;-&nbsp;#{to_price((max_price.to_i*c).to_i)}"
      end
    end
  end
  
  def old_price_str
    discount=get_discount
    if discount && discount>0
      if min_price == max_price
        "#{to_price(min_price)}"
      else
        # "<small>от</small> #{min_price} <small>до</small> #{max_price} <small>руб.</small>"
        "#{to_price(min_price)}&nbsp;-&nbsp;#{to_price(max_price)}"
      end
    else
      ""
    end
  end

  def main_image_url(version=:product_list)
    images.present? ? images.first.image.url(version) : "product_list_no_photo_#{Settings.theme}.png"
  end

end
