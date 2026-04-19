Rails.application.routes.draw do
  get "auto_uploads/index"
  get "category_imports/new"
  get "category_imports/create"
  root "home#index"
  get 'dashboard_data', to: 'home#dashboard_data', as: 'dashboard_data'
  get 'dashboard_category_transactions', to: 'home#dashboard_category_transactions', as: 'dashboard_category_transactions'
  get 'insights', to: 'home#insights', as: 'insights'
  get 'spending_breakdown', to: 'home#spending_breakdown', as: 'spending_breakdown'
  get 'spending_breakdown/data', to: 'home#spending_breakdown_data', as: 'spending_breakdown_data'
  get 'spending_breakdown/export', to: 'home#spending_breakdown_export', as: 'spending_breakdown_export'
  # Settings page and destructive actions
  get 'settings', to: 'settings#index', as: 'settings'
  post 'settings/clear_transactions', to: 'settings#clear_transactions', as: 'settings_clear_transactions'
  post 'settings/clear_categories', to: 'settings#clear_categories', as: 'settings_clear_categories'
  resources :transactions do
    patch :assign_category, on: :member
  end
  # Export categories YAML for download
  get 'categories/download_yaml', to: 'categories#download_yaml', as: 'download_categories_yaml'
  # Pie chart data endpoint
  get 'categories/pie_chart_data', to: 'categories#pie_chart_data', as: 'pie_chart_data'
  # Update category percentages from pie chart
  patch 'categories/update_percentages', to: 'categories#update_percentages', as: 'update_categories_percentages'
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

  # Auto uploads
  get 'auto_uploads', to: 'auto_uploads#index', as: 'auto_uploads'
  post 'auto_uploads/update_folder', to: 'auto_uploads#update_folder', as: 'update_auto_upload_folder'

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
