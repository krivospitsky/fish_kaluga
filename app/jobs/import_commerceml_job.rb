#encoding: utf-8

class ImportCommercemlJob < ActiveJob::Base
  queue_as :default

  def perform(name)
	# return if Settings.theme == 'fish' && name =='import.xml'
	
	dir = "public/uploads/commerceml"
	path = File.join(dir, name)
		
	doc = File.open(path) { |f| Nokogiri::XML(f) }
	doc.remove_namespaces!

	puts "#{name} открыт"

	if Settings.theme != 'fish'
		doc.xpath("КоммерческаяИнформация/Классификатор/Группы/Группа").each do |group|
			process_group(group)    			
		end
	end

	total=0
	not_found=0

	doc.xpath("КоммерческаяИнформация/Каталог/Товары/Товар").each do |prod|    			
		# puts "Товар"

		total+=1

		if Settings.theme == 'fish'
			id=get_xpath_val(prod, "Ид")
			variant=Variant.find_by(external_id: id)	
			next if variant

			shtrih=get_xpath_val(prod, "Штрихкод")
			variant=Variant.find_by(sku: shtrih) if shtrih
			unless variant
				sku=get_xpath_val(prod, "Артикул")
				variant=Variant.find_by(sku: sku) if sku
			end

			if variant
				variant.external_id=id
				variant.save
			else
				# puts "variant #{shtrih} - #{sku} not found"
				not_found+=1
			end			
		else

			product=Product.find_or_initialize_by(external_id: prod.xpath('Ид').first.content.strip)
			product.sku=prod.xpath('Артикул').first.content.strip
			product.name=prod.xpath('Наименование').first.content.strip

			puts product.name

			prod.xpath('ЗначенияРеквизитов/ЗначениеРеквизита').each do |rec|    			
				if rec.xpath('Наименование').first.content == 'Полное наименование'
					product.description = rec.xpath('Значение').first.content.strip.gsub("\n", "<br>\n")
				end
			end

			product.categories.delete_all
	        prod.xpath('Группы/Ид').each do |cat|
	        	product.categories << Category.find_by(external_id: cat.content.strip)
	        end

			prod.xpath('ЗначенияСвойств/ЗначенияСвойства').each do |prop|
				puts prop.xpath('Ид').first.content.strip
				puts prop.xpath('Значение').first.content.strip
				case prop.xpath('Ид').first.content.strip
				when '1ecf26b9-f45d-11e7-7a31-d0fd000fcb45'
					product.yml_name=prop.xpath('Значение').first.content.strip
				when '2316502d-f3ab-11e7-7a34-5acf0009c818'
					product.typePrefix=prop.xpath('Значение').first.content.strip
				when '5c36885e-f212-11e7-6b01-4b1d00370175'
					product.vendor=prop.xpath('Значение').first.content.strip
				when '23165371-f3ab-11e7-7a34-5acf0009c819'
					product.model=prop.xpath('Значение').first.content.strip
				when '690a2d08-f20a-11e7-7a34-5acf003582ed'
					product.color=prop.xpath('Значение').first.content.strip
				when '231655a3-f3ab-11e7-7a34-5acf0009c81a'
					product.picture_type=prop.xpath('Значение').first.content.strip
				end
			end

	        product.save
	    end
	end

	puts "prod total #{total}, not found #{not_found}"

	total=0
	not_found=0

	doc.xpath("КоммерческаяИнформация/ПакетПредложений/Предложения/Предложение").each do |var|    			
		# puts "предложение"
		total+=1
		if Settings.theme == 'fish'
			variant=Variant.find_by(external_id: var.xpath("Ид").first.content.strip)
			if variant
				variant.count=var.xpath('Количество').first.content.strip
				if variant.count>0
					variant.availability='В наличии'
					variant.enabled=true
					product=variant.product

			        if product.enabled != true
				        puts "enabling  #{product.name}"
			        	product.enabled=true
			        	product.returned_at=Time.now()
			        	product.save
			        end
			    else
					variant.availability='Нет в наличии'
					variant.enabled=false			    	
				end			    	
		        variant.save
		    else
		    	# puts "variant #{var.xpath('Ид').first.content.strip} not found"
		    	not_found+=1
		    end
		else
			variant=Variant.find_or_initialize_by(external_id: var.xpath('Ид').first.content.strip)
			variant.product=Product.find_by(external_id: variant.external_id.split('#')[0])
			var.xpath('Цены/Цена').each do |price|
				if price.xpath('ИдТипаЦены').first.content.strip == 'cbcf493b-55bc-11d9-848a-00112f43529a'
					variant.price=price.xpath('ЦенаЗаЕдиницу').first.content.strip
				end
			end
			variant.count=var.xpath('Количество').first.content.strip
			if variant.count>0
				variant.availability='В наличии'
				variant.enabled=true
		        product=variant.product
		        # puts "!!! #{product.name} !! #{product.enabled}"
		        if product.enabled != true
			        puts "enabling  #{product.name}"
		        	product.enabled=true
		        	product.returned_at=Time.now()
		        	product.save
		        end

			else
				variant.availability='Нет в наличии'
				variant.enabled=false
			end

			variant.name=variant.product.name    			
			variant.sku=variant.product.sku
			variant.attrs.delete_all
			first_var=true
			var_exist=false
			var.xpath('ХарактеристикиТовара/ХарактеристикаТовара').each do |v_attr|
				if first_var
					variant.name+=' ('
				else
					variant.name+=', '    					
				end
				a=variant.attrs.new
				a.name=v_attr.xpath('Наименование').first.content.strip
				a.value=v_attr.xpath('Значение').first.content.strip
				if a.value.match(/\((.+)\)/)
					puts "#{a.value} -> #{Regexp.last_match[1]}"
					a.value=Regexp.last_match[1]
				end
				a.save
				variant.name+= "#{a.name.mb_chars.downcase.to_s} #{a.value}"
				variant.sku+="_#{a.value}"
				first_var=false
				var_exist=true
			end
			variant.name+=')' if var_exist
			puts variant.name
			variant.save    			
		end
	end

	puts "variants total #{total}, not found #{not_found}"


	if name =='offers.xml' && Settings.theme != 'fish'
		# Variant.where("updated_at < ? and updated_at >= ?", 1.day.ago, 2.week.ago, like_str).update_all(availability: 'Уточнить у менеджера')
		Product.all.each do |prod|
			if prod.variants.enabled.empty?
				puts "товар #{prod.name} недоступен"
				prod.enabled=false
				prod.save
			end
		end		
		if Settings.theme == 'mama40'
			`rake -f #{Rails.root.join("Rakefile")} moysklad:import_photos`
			`rake -f #{Rails.root.join("Rakefile")} moysklad:import_users`
		end
	end
  end

	private

	def process_group(group, parent_gr=nil)
		category=Category.find_or_initialize_by(external_id: group.xpath('Ид').first.content.strip )
		category.name=group.xpath('Наименование').first.content.strip
		puts category.name
		category.parent=parent_gr if parent_gr
		category.enabled=true if category.new_record?
		category.save

		group.xpath('Группы/Группа').each do |sub_group|
			process_group(sub_group, category)
		end
	end

end


def get_xpath_val(node, xpath)
	res=node.xpath(xpath)
	if res.length
		return res.text
	else
		return nil
	end
end