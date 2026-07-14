class PlantsController < ApplicationController
  PLANTS_PER_PAGE = 24

  def index
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
