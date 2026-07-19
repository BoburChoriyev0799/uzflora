class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :set_locale

  def switch_locale
    locale = params[:locale].to_sym
    if I18n.available_locales.include?(locale)
      I18n.locale = locale
      cookies.permanent[:locale] = locale
      # current_user.update_attributes(locale: locale.to_s) if current_user
    end

    redirect_back(fallback_location: '/', allow_other_host: false)
  end

  # ActiveAdmin chaqiradi (config.on_unauthorized_access, config/
  # initializers/active_admin.rb) — admin bo'lmagan foydalanuvchi /admin
  # ostidagi biror sahifaga kirmoqchi bo'lganda. MUHIM: bu yerda
  # dashboard'ga (yoki boshqa /admin sahifasiga) QAYTARILMAYDI — aks
  # holda o'sha sahifaga ham ruxsat bo'lmagani uchun cheksiz redirect
  # loop hosil bo'ladi (ActiveAdmin'ning o'zi shuni ogohlantirgan edi).
  # root_path — oddiy ommaviy sahifa, hech qanday admin tekshiruviga
  # bog'liq emas, shuning uchun loop bo'lishi mumkin emas.
  def admin_access_denied(_exception = nil)
    redirect_to root_path, alert: I18n.t('errors.messages.admin_access_denied')
  end

  private

  def set_locale
    I18n.locale = cookies.permanent[:locale] || I18n.default_locale
  end
end
