Rails.application.routes.draw do
  # Admin authentication - Devise only for admin users
  devise_for :users, skip: [:registrations], path: 'admin_auth'

  ActiveAdmin.routes(self)

  root "home#index"

  resources :prefectures, only: [:show], param: :slug
  resources :shops, only: [:show], param: :slug do
    member do
      get "dates/:date", action: :show_date, as: :date, constraints: { date: /\d{4}-\d{2}-\d{2}/ }
    end
  end
  resources :machines, only: [:show], param: :slug
  resources :votes, only: [:create, :update]
  resources :comments, only: [:create]
  resources :reports, only: [:create]

  get "up" => "rails/health#show", as: :rails_health_check
end
