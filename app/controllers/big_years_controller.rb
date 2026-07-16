class BigYearsController < ApplicationController
  before_action :authenticate_user!, only: [:change_subscription]

  def index
    @current_year = Time.zone.now.year
    @participants = Statistics::BigYear.plant_users_ranking(@current_year)
  end

  # MUHIM: `render nothing: true` Rails 7'da endi qo'llab-quvvatlanmaydi —
  # bu action shu sababli har doim 500 (Template is missing) xato berardi,
  # garchi obuna o'zi to'g'ri saqlansa ham (foydalanuvchi hech qanday
  # tasdiq ko'rmasdi). `render json:` bilan almashtirildi.
  def change_subscription
    year = Time.zone.now.year
    action = (params[:big_year] == '1' ? :subscribe! : :unsubscribe!)
    current_user.send(action, year)
    render json: { subscribed: current_user.subscribed?(year) }
  end

end
