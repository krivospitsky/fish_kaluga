Shop::Application.routes.draw do
  devise_for :users
  devise_for :admins

  mount Ckeditor::Engine => '/ckeditor'
  
  Blogo::Routes.mount_to(self, at: '/blog')

  resources :pages#, as: :original_page
  # resources :promotions
#  resources :categories
#  resources :products

  get 'catalog/search' => 'products#search'
  get 'catalog/product/:id', to: 'products#show', as: :canonical_product
  get 'catalog(/*category_path)/:category_id/product/:id', to: 'products#show', as: :original_product
  #get 'catalog(/*category_path)/:category_id/product/:id', to: 'products#show', as: :original_product
  get 'catalog(/*category_path)/:category_id/', to: 'products#index', as: :category
  get 'catalog', to: 'products#index'
#  resources :main

 # get 'login' => 'auth#index'
#  get '/cart', to: 'orders#new', as: '/cart'
  resources :cart_items
  get '/cart/delete/:product_id' => 'cart#delete'
  post '/cart/add' => 'cart#add'

  post '/callback' => 'callback#new'


  resources :orders do
    # get :order, on: :collection
    # get :finish, on: :collection

    get :after_pay, on: :collection
    get :after_pay_error, on: :collection
    post :ya_kassa_check, on: :collection, defaults: { format: 'xml' }
    post :ya_kassa_payment, on: :collection, defaults: { format: 'xml' }
    post :ya_money_payment, on: :collection
  end
  get '/order/checkout' => 'orders#checkout'

    # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
#  root 'pages#show', id: Page.first.id
#  root 'products#index'
  root 'main#show'

  if ActiveRecord::Base.connected? 
    get "/#{Settings.google_verification}.html",
      to: proc { |env| [200, {}, ["google-site-verification: #{Settings.google_verification}.html"]] }
    get "/yandex_#{Settings.yandex_verification}.txt",
      to: proc { |env| [200, {}, ["yandex_verification"]] }
    get "/yandex_#{Settings.yandex_verification}.html",
      to: proc { |env| [200, {}, ["<html><head><meta http-equiv='Content-Type' content='text/html; charset=UTF-8'></head><body>Verification: #{Settings.yandex_verification}</body></html>"]] }
  end

  %w( 404 500 ).each do |code|
    get code, :to => "errors#show", :code => code
  end

  get '/check.txt', to: proc {[200, {}, ['simple_check']]}

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  namespace :admin do
    resources :products do
      get :copy, on: :member
    end
    resources :categories do
      get :autocomplete, :on => :collection
    end
    resources :pages
    resources :orders
    resources :discounts
    resources :slides
    resources :users
    resources :delivery_methods
    resources :payment_methods
    resources :blogo_posts
    get '/settings/edit' => '/admin/settings#edit'
    post '/settings/edit' => '/admin/settings#update'
    get '/moscanella/new' => '/admin/moscanella#new'
    post '/moscanella/import' => '/admin/moscanella#import'

    get '/1c_exchange.php' => '/admin/commerce_ml#exchange'
    post '/1c_exchange.php' => '/admin/commerce_ml#exchange'
  end


end
