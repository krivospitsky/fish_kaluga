class RecreateImagesJob < ActiveJob::Base
  queue_as :default

  def perform()
    Product.all.each{|p| p.images.all.each{|i| i.image.recreate_versions!}}
  end
end
