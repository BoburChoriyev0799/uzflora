class UsersController < Devise::RegistrationsController
  before_action :only => [:change_password, :unregister] do
    authenticate_user!(force: true)
  end
  before_action :configure_permitted_parameters, :only => [:create]
  before_action :authenticate_user!, :require_admin!, only: [:toggle_expert]
  # DIQQAT: oddiy `before_action :authenticate_user!` Devise'ning o'zidan
  # meros olgan controller'larda (`devise_controller?` true bo'lganda)
  # `force: true` bo'lmasa JIM turadi (Devise::Controllers::Helpers#
  # define_helpers: `warden.authenticate!(opts) if !devise_controller? ||
  # opts.delete(:force)`) — ya'ni bu yerda (`UsersController <
  # Devise::RegistrationsController`) himoyasiz qoladi. Yuqoridagi
  # change_password/unregister uchun `force: true` allaqachon shu sababdan
  # ishlatilgan — follow/unfollow uchun ham xuddi shu naqsh kerak.
  before_action(only: [:follow, :unfollow]) { authenticate_user!(force: true) }

  #TODO!!!:: remove to separate controller!!
  def index
    @users = Statistics::Counts.users_birds
    @big_year_users_count = Statistics::BigYear.users_count
  end

  # Faqat admin (require_admin!) — boshqa foydalanuvchining ekspert
  # holatini yoqadi/o'chiradi. Admin'ning o'ziga (is_admin) tegmaydi,
  # faqat is_expert ustunini almashtiradi.
  def toggle_expert
    user = User.find(params[:id])
    user.update!(is_expert: !user.is_expert?)
    redirect_to users_path
  end

  # reCAPTCHA vaqtincha o'chirilgan — kalit (BIRDS_RECAPTCHA_KEY) hech qachon
  # sozlanmagan edi, shuning uchun ro'yxatdan o'tish butunlay ishlamas edi.
  # gem/initializer saqlanib qoldi, kerak bo'lsa qayta yoqish oson bo'lsin.
  def create
    super do |user|
      user.subscribe!(Time.zone.now.year) if user.big_year
    end
  end

  # Bir tomonlama kuzatish — qabul/rad qilish yo'q. O'zini o'zi kuzatish
  # bu yerda (server tomonda) ham tekshiriladi — view'da tugma
  # ko'rsatilmasligi yagona himoya bo'lib qolmasin (masalan to'g'ridan-to'g'ri
  # so'rov yuborilsa). `User#follow` model darajasida ham xuddi shu
  # tekshiruvni takrorlaydi (`Follow#cannot_follow_self`), shu bilan birga
  # unikal indeks parallel so'rovlardan (qo'sh bosish) himoya qiladi.
  def follow
    target = User.find(params[:id])
    if target.id == current_user.id
      render json: { success: false, error: I18n.t('profile.follow.cannot_follow_self') }, status: :unprocessable_entity
      return
    end

    if current_user.follow(target)
      render json: { success: true, following: true, followers_count: target.followers.count }
    else
      render json: { success: false, error: I18n.t('profile.follow.error') }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    render json: { success: true, following: true, followers_count: target.followers.count }
  end

  def unfollow
    target = User.find(params[:id])
    current_user.unfollow(target)
    render json: { success: true, following: false, followers_count: target.followers.count }
  end

  def change_password
    @user = User.find(current_user.id)
    if @user.update(user_params)
      # Sign in the user bypassing validation in case his password changed
      sign_in @user, :bypass => true
      redirect_to after_update_path_for(@user)
    else
      render 'profiles/show'
    end
  end

  private
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :big_year])
  end

  def require_admin!
    redirect_to root_path unless current_user.try(:admin?)
  end

  def user_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
