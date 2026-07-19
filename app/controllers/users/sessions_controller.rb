# Parol to'g'ri, lekin akkauntda 2FA (otp_required_for_login) yoqilgan
# bo'lsa, standart Devise oqimini to'xtatib, foydalanuvchini alohida
# "kod kiritish" sahifasiga yo'naltiradi (Users::OtpSessionsController).
# Sign in FAQAT kod tasdiqlangach amalga oshadi. 2FA yoqilmagan
# foydalanuvchilar (hozircha barcha oddiy user/ekspertlar) uchun bu
# controller shunchaki `super`ga o'tadi — ularning kirish oqimi
# o'zgarmaydi.
class Users::SessionsController < Devise::SessionsController
  def create
    user = User.find_for_database_authentication(email: sign_in_params[:email])

    if user && user.valid_password?(sign_in_params[:password]) && user.otp_required_for_login?
      session[:otp_user_id] = user.id
      redirect_to new_user_otp_path
      return
    end

    super
  end

  private

  def sign_in_params
    params.fetch(:user, {}).permit(:email, :password)
  end
end
