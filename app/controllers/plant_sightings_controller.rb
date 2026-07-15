class PlantSightingsController < ApplicationController
  before_action :authenticate_user!, except: [:show]

  layout 'plant_map', only: [:edit_map, :show]

  def show
    @plant_sighting = PlantSighting.find(params[:id])
  end

  def new
    @plant_sighting = PlantSighting.new
  end

  def create
    permit_params = plant_sighting_params
    if permit_params[:photo].blank?
      redirect_to new_plant_sighting_path, alert: t('.photo_required')
      return
    end

    sighting = PlantSighting.new(permit_params)
    sighting.user = current_user

    if sighting.save
      redirect_to action: :edit_date, id: sighting.id
    else
      redirect_to new_plant_sighting_path, alert: sighting.errors.full_messages.to_sentence
    end
  end

  def edit_date
    @plant_sighting = PlantSighting.find(params[:id])
    @timestamp = @plant_sighting.timestamp ||
                 current_user.plant_sightings.where.not(timestamp: nil).order(created_at: :desc).limit(1).pluck(:timestamp).first ||
                 Time.zone.now
  end

  def edit_map
    @plant_sighting = PlantSighting.find(params[:id])
  end

  def edit_plant
    @plant_sighting = PlantSighting.find(params[:id])
  end

  def update
    @plant_sighting = PlantSighting.find(params[:id])

    if @plant_sighting.update(plant_sighting_params)
      redirect_to action: next_edit_action(@plant_sighting), id: @plant_sighting.id
    else
      redirect_to action: :edit_date, id: @plant_sighting.id, alert: @plant_sighting.errors.full_messages.to_sentence
    end
  end

  def publish
    @plant_sighting = PlantSighting.find(params[:id])
    @plant_sighting.update(plant_sighting_params)
    redirect_to plant_sighting_path(@plant_sighting)
  end

  def destroy
    sighting = PlantSighting.find(params[:id])
    return redirect_to plants_path unless sighting.owner?(current_user)

    sighting_published = sighting.published
    PlantSighting.destroy(sighting.id)
    sightings_count = sighting_published ? current_user.plant_sightings.published.count : current_user.plant_sightings.unpublished.count
    render json: { published: sighting_published, count: sightings_count }
  end

  # AJAX: Plant.search orqali o'simlik nomi qidiruvi (lotin/rus/o'zbek).
  def search_plant
    @plants = params[:text].present? ? Plant.search(params[:text]).limit(20) : Plant.none
    respond_to do |format|
      format.js
    end
  end

  private

  def plant_sighting_params
    params.require(:plant_sighting).permit(
      :photo,
      :photo_cache,
      :timestamp,
      :latitude,
      :longitude,
      :address,
      :note,
      :plant_id
    )
  end

  def next_edit_action(sighting)
    if sighting.timestamp.blank?
      :edit_date
    elsif sighting.latitude.blank? || sighting.longitude.blank?
      :edit_map
    else
      :edit_plant
    end
  end
end
