Birds::Application.routes.draw do
  ActiveAdmin.routes(self)

  devise_for :users,
             :controllers => { registrations: 'users',
                               omniauth_callbacks: 'users/omniauth_callbacks' },
             path: '/user',
             skip: :registrations

  devise_scope :user do
    get 'users', to: 'users#index'
    post 'user', to: 'users#create', as: :user_registration
    get 'user/sign_up', to: 'users#new', as: :new_user_registration
    put 'user/change_password', to: 'users#change_password'
    get 'user/unregister', to: 'users#unregister', as: :user_unregister
  end

  resources :profiles, only: [:show, :update]

  root to: 'plants#index'

  get 'switch_locale' => 'application#switch_locale'

  resource :pages, path: '', only: [] do
    get :about
    get :birding_rules
    get :approve
    get :show_new
    get :show_commentable
    get :show_unknown
    get :help
  end

  resource :big_year, only: [] do
    get :index
    get :prises
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
    member do
      get 'edit_date' => 'plant_sightings#edit_date'
      get 'edit_map' => 'plant_sightings#edit_map'
      get 'edit_plant' => 'plant_sightings#edit_plant'
      post 'publish' => 'plant_sightings#publish'
    end
  end

  post 'plant_sightings_search' => 'plant_sightings#search_plant'

  resources :categories, only: [:index]

  resources :comments, only: [:create, :destroy]

  resource :search, path: '', only: [] do
    get 'search' => 'search#index'
    post 'search' => 'search#search'
    post 'main_species' => 'search#search_main_species'
  end

  resource :swift, only: [] do
    get 'first_aid'
    get 'about'
  end

  get 'become/:id', to: 'admin#become'

end
