Rails.application.routes.draw do
  root "home#index"

  devise_for :users

  post "webhook", to: "webhooks#create", as: :webhook

  namespace :admin do
    get "dashboard/index"
    resource :droplet, only: %i[ create update ]
    resources :settings, only: %i[ index edit update ]
    resources :users
  end
  get "shipstation" => "shipstation#export"
  post "shipstation" => "shipstation#notify"
  get "embed_ui" => "embed#index", as: :embed_ui

  get "up" => "rails/health#show", as: :rails_health_check
end
