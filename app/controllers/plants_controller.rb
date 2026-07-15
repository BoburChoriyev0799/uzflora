class PlantsController < ApplicationController
  PLANTS_PER_PAGE = 24

  # Mehmon (ro'yxatdan o'tmagan) foydalanuvchi uchun — o'simliklar ro'yxati
  # o'rniga faqat ko'rsatuv uchun mo'ljallangan "kirish oynasi" (karusel +
  # xarita). Ichkariga (kataloг, profil va h.k.) kirish faqat tizimga
  # kirgandan keyin ochiladi.
  def index
    if current_user.blank?
      # 5 tadan ko'p olamiz (galereya 5 katakda ko'rsatadi, lekin har 5
      # soniyada navbatdagi 5 tasiga "varaqlanadi" — shuning uchun aylanish
      # uchun ko'proq material kerak).
      @recent_sightings = PlantSighting.published.approved
                                        .includes(:plant, :user)
                                        .order(created_at: :desc)
                                        .limit(20)
      @map_sightings = PlantSighting.published.approved
                                     .where.not(latitude: nil, longitude: nil)
      render 'welcome'
      return
    end

    @plants = Plant.all.order(:species_sci)
    @plants = @plants.search(params[:q]) if params[:q].present?
    @plants = @plants.by_family(params[:family]) if params[:family].present?
    @plants = @plants.red_listed if params[:red_book].present?
    @plants = @plants.page(params[:page]).per(PLANTS_PER_PAGE)

    @families = Plant.where.not(family_apg_sci: nil).distinct.order(:family_apg_sci).pluck(:family_apg_sci)
  end

  def show
    @plant = Plant.find(params[:id])
  end
end
