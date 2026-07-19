# Parol tekshiruvidan keyingi ikkinchi qadam: Authenticator ilovasidagi
# 6 xonali kod (yoki bitta zaxira kod) kiritiladi. session[:otp_user_id]
# Users::SessionsController#create tomonidan o'rnatiladi — bu qiymat
# bo'lmasa (sahifaga to'g'ridan-to'g'ri kirilsa), kirish sahifasiga
# qaytariladi.
class Users::OtpSessionsController < ApplicationController
  before_action :require_pending_otp_user!

  def new
  end

  def create
    code = params[:code].to_s.strip

    if @user.validate_and_consume_otp!(code)
      complete_sign_in!
    elsif @user.invalidate_otp_backup_code!(code) && @user.save
      complete_sign_in!
    else
      flash.now[:alert] = I18n.t('two_factor.otp_session.invalid_code')
      render :new, status: :unprocessable_entity
    end
  end

  private

  def require_pending_otp_user!
    @user = User.find_by(id: session[:otp_user_id])
    redirect_to new_user_session_path, alert: I18n.t('two_factor.otp_session.expired') unless @user
  end

  def complete_sign_in!
    session.delete(:otp_user_id)
    sign_in(@user, scope: :user)
    redirect_to after_sign_in_path_for(@user)
  end
end
