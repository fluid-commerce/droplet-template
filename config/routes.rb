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

  get "embed_ui" => "embed#index", as: :embed_ui

  get "up" => "rails/health#show", as: :rails_health_check

  post "get_redirect_url", to: "checkout_callback#get_redirect_url", as: :get_redirect_url
  get "checkout/success/:cart_token/payment_account/:payment_account_id",
      to: "checkout_callback#success",
      as: :checkout_success
  mount MissionControl::Jobs::Engine, at: "/jobs"
end
