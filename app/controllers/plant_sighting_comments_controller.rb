class PlantSightingCommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :filter_users

  def create
    if params[:comment].blank? || params[:plant_sighting_id].blank?
      render json: { success: false }
      return
    end

    comment = PlantSightingComment.new(text: params[:comment])
    comment.user = current_user
    comment.plant_sighting_id = params[:plant_sighting_id]

    if comment.save
      render json: {
        success: true,
        id: comment.id,
        text: comment.text,
        user_name: current_user.full_name,
        user_avatar: current_user.avatar.thumb.url,
        user_profile: profile_path(current_user)
      }
    else
      render json: { success: false }
    end
  end

  def destroy
    comment = PlantSightingComment.find(params[:id])
    comment.destroy if comment.owner?(current_user)
    render json: { count: current_user.plant_sighting_comments.count }
  end

  private

  def filter_users
    return render json: { success: false } if current_user.try(:restricted?)
  end
end
