class UsersController < Devise::RegistrationsController
  before_action :only => [:change_password, :unregister] do
    authenticate_user!(force: true)
  end
  before_action :configure_permitted_parameters, :only => [:create]
  before_action :authenticate_user!, :require_admin!, only: [:toggle_expert]

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
