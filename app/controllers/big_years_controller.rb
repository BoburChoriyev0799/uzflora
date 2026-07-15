class BigYearsController < ApplicationController

  def index
    @current_year = Time.zone.now.year
  end

  def change_subscription
    action = (params[:big_year] == '1' ? :subscribe! : :unsubscribe!)
    current_user.send(action, Time.zone.now.year)
    render nothing: true
  end

end
