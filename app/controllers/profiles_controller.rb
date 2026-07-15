class ProfilesController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = User.find(params[:id])
    viewing_own_profile = @user.current?(current_user)

    @big_year_species_count = Statistics::BigYear.user_approved_count(@user.id, Time.zone.now.year)
    @big_year_rating = Statistics::BigYear.user_ranking(@user.id, Time.zone.now.year)
    @species = Statistics::Counts.user_plants(@user.id)

    #TODO: separate pagination of sightings and comments
    sightings = PlantSighting.includes(:plant).published.by_user(@user.id)
    # Boshqa foydalanuvchilar faqat ekspert tasdiqlagan kuzatuvlarni ko'radi —
    # egasi esa kutilayotgan/rad etilganlarini ham status belgisi bilan ko'radi.
    sightings = sightings.approved unless viewing_own_profile
    @birds = sightings.order(created_at: :desc).page(params[:page_birds]).per(18)
    @drafts = PlantSighting.includes(:plant).unpublished.by_user(@user.id).order(created_at: :desc)
    @comments = Comment.where(user_id: @user.id).order(created_at: :desc).page(params[:page_comments]).per(15)

    respond_to do |format|
      format.html
      format.js
    end
  end
  
  def update
    current_user.update editable_params

    respond_to do |format|
      format.html { redirect_to  action: :show }
      format.json { respond_with_bip current_user }
    end
  end

  private
  def editable_params
    params.require(:user).permit(:avatar, :first_name, :last_name)
  end
end
