# Admin akkaunti uchun 2FA (TOTP) sozlamalari — yoqish/tasdiqlash/o'chirish.
# FAQAT admin (is_admin) uchun mavjud: oddiy foydalanuvchi va ekspertlar
# admin panelga kirmagani uchun ularga 2FA shart emas.
class TwoFactorAuthController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  def show
  end

  # 1-qadam: yangi maxfiy kalit generatsiya qilinadi (hali
  # otp_required_for_login yoqilmagan — kod tasdiqlanmaguncha 2FA
  # kirishda talab qilinmaydi). QR kod shu kalit asosida ko'rsatiladi.
  def enable
    return redirect_to two_factor_auth_path if current_user.otp_required_for_login?

    current_user.otp_secret = User.generate_otp_secret
    current_user.save!(validate: false)
    redirect_to two_factor_auth_path
  end

  # 2-qadam: Authenticator ilovasidan olingan kodni tasdiqlash. To'g'ri
  # bo'lsa 2FA to'liq yoqiladi va bir martalik zaxira kodlar generatsiya
  # qilinib, FAQAT shu safar ko'rsatiladi (keyin qayta ko'rsatilmaydi).
  def confirm
    code = params[:code].to_s.strip

    if current_user.otp_secret.present? && current_user.validate_and_consume_otp!(code)
      current_user.otp_required_for_login = true
      @backup_codes = current_user.generate_otp_backup_codes!
      current_user.save!(validate: false)
      render :backup_codes
    else
      flash.now[:alert] = I18n.t('two_factor.setup.invalid_code')
      render :show
    end
  end

  # 2FA'ni o'chirish — joriy parol bilan tasdiqlanadi (boshqa birov
  # ochiq qolgan seans orqali o'chira olmasligi uchun).
  def disable
    if current_user.valid_password?(params[:current_password].to_s)
      current_user.otp_required_for_login = false
      current_user.otp_secret = nil
      current_user.consumed_timestep = nil
      current_user.otp_backup_codes = []
      current_user.save!(validate: false)
      redirect_to two_factor_auth_path, notice: I18n.t('two_factor.setup.disabled')
    else
      flash.now[:alert] = I18n.t('two_factor.setup.wrong_password')
      render :show
    end
  end

  private

  def require_admin!
    redirect_to root_path unless current_user.try(:admin?)
  end
end
