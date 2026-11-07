Rails.application.routes.draw do
  # Registers the Devise mapping but none of its default routes, so only the
  # endpoints below exist (no password reset, account edit or account delete).
  devise_for :users, skip: :all

  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      post "auth/signup", to: "auth/registrations#create"

      devise_scope :user do
        post "auth/login", to: "auth/sessions#create"
        delete "auth/logout", to: "auth/sessions#destroy"
      end

      get "me", to: "me#show"

      resource :availability, only: [ :show, :update ]
      resources :professionals, only: [ :index, :show ]
      resources :appointments, only: [ :index, :create ] do
        member do
          post :cancel
          post :reschedule
        end
      end
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
