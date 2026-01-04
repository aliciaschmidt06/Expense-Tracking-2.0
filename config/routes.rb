Rails.application.routes.draw do
  get "category_imports/new"
  get "category_imports/create"
  root "home#index"
  get 'dashboard_data', to: 'home#dashboard_data', as: 'dashboard_data'
  get 'dashboard_category_transactions', to: 'home#dashboard_category_transactions', as: 'dashboard_category_transactions'
  get 'insights', to: 'home#insights', as: 'insights'
  get 'spending_breakdown', to: 'home#spending_breakdown', as: 'spending_breakdown'
  resources :transactions do
    patch :assign_category, on: :member
  end
  # Export categories YAML for download
  get 'categories/download_yaml', to: 'categories#download_yaml', as: 'download_categories_yaml'
  # Show uncategorized transactions (Unknown category)
  get 'uncategorized', to: 'transactions#uncategorized', as: 'uncategorized_transactions'

  resources :categories
  
  resource :import, only: [:new] do
    post :transactions
  end

  # config/routes.rb
  resources :category_imports, only: [:new, :create]
  resources :imports, only: [:new] do
    post :transactions, on: :collection
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
