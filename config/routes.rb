Uzflora::Application.routes.draw do
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
    post 'users/:id/follow', to: 'users#follow', as: :follow_user
    delete 'users/:id/unfollow', to: 'users#unfollow', as: :unfollow_user
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

  resources :notifications, only: [:index, :show] do
    collection do
      get :recent
      post :mark_all_as_read
    end
  end

  root to: 'plants#index'

  get 'switch_locale' => 'application#switch_locale'

  resource :pages, path: '', only: [] do
    get 'qollab-quvvatlash', to: 'pages#donation', as: :donation
  end

  resource :big_year, only: [] do
    get :index
    post :change_subscription
  end

  # Rasm orqali o'simlik aniqlash (POST, AJAX) — faqat shu manzil GET
  # bilan TO'G'RIDAN-TO'G'RI ochilsa (havola ulashilgan, sahifa yangilangan
  # va h.k.), pastdagi `resources :plants`даgi `GET /plants/:id` (show)
  # bilan mos kelib, "identify"ni tur ID sifatida izlab 404 bermasin —
  # bu qator BIRINCHI turgani uchun ustunlik qiladi (Rails marshrutlarni
  # e'lon qilingan tartibda tekshiradi).
  get 'plants/identify', to: redirect('/plants')

  resources :plants, only: [:index, :show] do
    collection do
      post :identify
    end
  end

  # DonationsController — "Loyihani qo'llab-quvvatlash" formasi (yozuv
  # bazaga saqlanadi, pages#donation'dagi statik sahifadan farqli).
  # `donations_path` (ko'plik) — `donation_pages_path` (pages resursidagi
  # /qollab-quvvatlash) bilan chalkashmaydi, ikkalasi ham mustaqil.
  resources :donations, only: [:create] do
    collection do
      get :thanks
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
      post 'assign_plant' => 'plant_sightings#assign_plant'
      post 'identify' => 'plant_sightings#identify'
    end
    # Jamoaviy aniqlash (community identification) — `identify` (yuqorida,
    # PlantNet AI-aniqlash)dan ATAYLAB ALOHIDA nom/controller: ikkalasi
    # butunlay boshqa-boshqa narsa (biri bir martalik AI taxmin, ikkinchisi
    # foydalanuvchilar orasidagi ovoz berish).
    resources :identifications, only: [:create]
  end
  resources :identifications, only: [:destroy]

  post 'plant_sightings_search' => 'plant_sightings#search_plant'
  get 'plant_sightings_autocomplete' => 'plant_sightings#autocomplete', as: :plant_sightings_autocomplete

  resources :plant_sighting_comments, only: [:create, :destroy]

  get 'become/:id', to: 'admin#become'

end
