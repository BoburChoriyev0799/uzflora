Birds::Application.routes.draw do
  ActiveAdmin.routes(self)

  devise_for :users,
             :controllers => { registrations: 'users',
                               omniauth_callbacks: 'users/omniauth_callbacks',
                               sessions: 'users/sessions' },
             path: '/user',
             skip: :registrations

  devise_scope :user do
    get 'users', to: 'users#index'
    post 'users/:id/toggle_expert', to: 'users#toggle_expert', as: :toggle_expert_user
    post 'user', to: 'users#create', as: :user_registration
    get 'user/sign_up', to: 'users#new', as: :new_user_registration
    put 'user/change_password', to: 'users#change_password'
    get 'user/unregister', to: 'users#unregister', as: :user_unregister

    # Parol to'g'ri kiritilgach, agar akkauntda 2FA yoqilgan bo'lsa,
    # Users::SessionsController shu sahifaga yo'naltiradi (kirish hali
    # tugallanmagan — sign_in faqat kod tasdiqlangach chaqiriladi).
    get 'user/otp', to: 'users/otp_sessions#new', as: :new_user_otp
    post 'user/otp', to: 'users/otp_sessions#create', as: :user_otp
  end

  # Admin uchun ikki bosqichli tasdiqlash (2FA) sozlamalari — profildagi
  # "2FA sozlamalari" havolasi shu yerga olib boradi.
  get    'two_factor_auth',         to: 'two_factor_auth#show',    as: :two_factor_auth
  post   'two_factor_auth/enable',  to: 'two_factor_auth#enable',  as: :enable_two_factor_auth
  post   'two_factor_auth/confirm', to: 'two_factor_auth#confirm', as: :confirm_two_factor_auth
  delete 'two_factor_auth',         to: 'two_factor_auth#disable', as: :disable_two_factor_auth

  resources :profiles, only: [:show, :update]

  root to: 'plants#index'

  get 'switch_locale' => 'application#switch_locale'

  resource :pages, path: '', only: [] do
    get :about
    get :approve
    get 'qollab-quvvatlash', to: 'pages#donation', as: :donation
  end

  resource :big_year, only: [] do
    get :index
    post :change_subscription
  end

  resources :species, only: [:show]

  resources :plants, only: [:index, :show]

  resources :map, only: [:index]

  resources :birds, except: [:index] do
    member do
      get 'edit_date' => 'birds#edit_date'
      get 'edit_map' => 'birds#edit_map'
      get 'edit_species' => 'birds#edit_species'
      get 'publish' => 'birds#publish'
      post 'approve' => 'birds#approve'
    end
  end

  resources :plant_sightings, except: [:index] do
    collection do
      get 'pending' => 'plant_sightings#pending'
    end
    member do
      get 'edit_date' => 'plant_sightings#edit_date'
      get 'edit_map' => 'plant_sightings#edit_map'
      get 'edit_plant' => 'plant_sightings#edit_plant'
      post 'publish' => 'plant_sightings#publish'
      post 'approve' => 'plant_sightings#approve'
      post 'reject' => 'plant_sightings#reject'
    end
  end

  post 'plant_sightings_search' => 'plant_sightings#search_plant'

  resources :comments, only: [:create, :destroy]

  resources :plant_sighting_comments, only: [:create, :destroy]

  resource :search, path: '', only: [] do
    get 'search' => 'search#index'
    post 'search' => 'search#search'
    post 'main_species' => 'search#search_main_species'
  end

  get 'become/:id', to: 'admin#become'

end
