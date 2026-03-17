require "sidekiq/web"

Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }

  authenticated :user, ->(user) { user.role_owner? || user.role_admin? } do
    mount Sidekiq::Web => "/sidekiq"
  end

  namespace :admin do
    root "dashboard#index"

    resources :sessions, only: [ :index, :show ] do
      member do
        patch :approve_review
        patch :request_follow_up
        patch :reopen
        patch :update_review
        patch :assign_owner
      end

      resources :field_values, only: [ :edit, :update ], controller: :session_field_values
    end

    resources :flows do
      member do
        patch :publish
        patch :revert_to_draft
        patch :archive
      end

      resources :field_groups, except: [ :index, :show ] do
        member do
          patch :archive
          patch :move
        end
      end

      resources :fields, except: [ :index, :show ] do
        member do
          patch :archive
          patch :move
        end
      end
    end
    resource :whatsapp, only: [ :show, :new, :create, :edit, :update ], controller: :whatsapp
    resources :files, only: [ :index, :show ]
    resources :team_members, only: [ :index, :new, :create, :edit, :update ] do
      member do
        patch :deactivate
        patch :reactivate
      end
    end
    resource :billing, only: [ :show ], controller: :billing
    resource :settings, only: [ :show, :update ]
  end

  namespace :webhooks do
    resource :whatsapp, only: [ :show, :create ], controller: :whatsapp
  end

  namespace :api do
    namespace :v1 do
      resources :intake_sessions, only: [] do
        member do
          get :conversation_state
          post :conversation_response, to: "conversation_responses#create"
        end
      end
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "admin/dashboard#index"
end
