Rails.application.routes.draw do
  root "home#index"

  devise_for :users

  namespace :admin do
    get "dashboard/index"
    resource :droplet, only: %i[ create update ]
    resources :settings, only: %i[ index edit update ]
    resources :users
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
