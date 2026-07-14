Rails.application.routes.draw do
  # Admin authentication - Devise only for admin users
  devise_for :users, skip: [ :registrations ], path: "admin_auth"

  ActiveAdmin.routes(self)

  root "home#index"

  resources :prefectures, only: [ :show ], param: :slug
  resources :shops, only: [ :show ], param: :slug do
    collection do
      get :favorites
      get :nearby
      get :autocomplete
      get :machines_for_shop
    end
    member do
      get "dates/:date", action: :show_date, as: :date, constraints: { date: /\d{4}-\d{2}-\d{2}/ }
      get :trend_data
      get :trend_section
      get :calendar
      get :events_body
      get :comments_body
    end
    resources :shop_reviews, only: [ :create ], path: "reviews"
    resources :shop_events, only: [ :create ], path: "events"
  end
  resources :machines, only: [ :show ], param: :slug do
    collection do
      get :search
      get :autocomplete
    end
  end
  resources :votes, only: [ :create, :update ]
  resources :play_records, only: [ :index, :create, :update, :destroy ]
  resources :comments, only: [ :create ]
  resources :reports, only: [ :create ]
  resources :exchange_rate_reports, only: [ :create ]
  resources :feedbacks, only: [ :new, :create ]
  resources :shop_requests, only: [ :new, :create, :show ]

  # Promotion クリック計測 + 外部リダイレクト (/p/:id → ASP)
  get "p/:id", to: "promotions#click", as: :promotion_click

  resources :rankings, only: [ :index ]

  get "voter/status", to: "voter#status", as: :voter_status
  post "voter/restore", to: "voter#restore", as: :restore_voter_token
  patch "voter/display_name", to: "voter#update_display_name", as: :voter_display_name

  get "search", to: "search#index"

  get "up" => "rails/health#show", as: :rails_health_check

  # Static pages (legal / about)
  get "privacy",       to: "pages#privacy"
  get "terms",         to: "pages#terms"
  get "legal/tokushou", to: "pages#tokushou", as: :tokushou
  get "about",         to: "pages#about"

  # Error pages
  match "/404", to: "errors#not_found", via: :all
  match "/500", to: "errors#internal_server_error", via: :all
end
