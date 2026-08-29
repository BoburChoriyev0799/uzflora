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
      # Server render qilingan Haml partial (auto-escape) — JS tomonida
      # xom matndan HTML yig'ish YO'Q, shuning uchun XSS xavfi yo'q.
      render json: {
        success: true,
        id: comment.id,
        html: render_to_string(partial: 'plant_sightings/comment', formats: [:html], locals: { comment: comment })
      }
    else
      render json: { success: false, error: comment.errors.full_messages.to_sentence }
    end
  end

  def destroy
    comment = PlantSightingComment.find(params[:id])
    sighting = comment.plant_sighting
    comment.destroy if comment.deletable_by?(current_user)
    # `count` — o'zgarmagan (mavjud) semantika: joriy foydalanuvchining
    # JAMI izohlar soni. `comments_count` — YANGI, shu KUZATUVning
    # (ustidagi 💬 belgisi uchun) qolgan izohlar soni.
    render json: { count: current_user.plant_sighting_comments.count, comments_count: sighting.reload.comments_count }
  end

  private

  def filter_users
    return render json: { success: false } if current_user.try(:restricted?)
  end
end
