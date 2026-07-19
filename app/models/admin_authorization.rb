class AdminAuthorization < ActiveAdmin::AuthorizationAdapter
  # Ilgari user.has_role?(:admin) tekshirilardi — bu eski, hech qachon
  # seed qilinmagan Role tizimi, shuning uchun HAMMA uchun doim false
  # qaytarardi (tasodifan "yopiq", lekin buzuq holat — redirect loop
  # bilan birga). Endi haqiqiy is_admin ustuniga bog'landi.
  def authorized?(action, subject = nil)
    user.try(:admin?)
  end
end
