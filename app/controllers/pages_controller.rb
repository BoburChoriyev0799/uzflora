class PagesController < ApplicationController
  # comments/_preview.html.haml (birds/_photo.html.haml orqali #approve
  # sahifasida ishlatiladi) shu konstantaga bog'liq.
  COMMENT_MAX_LENGTH = 64

  def approve
    @birds = Bird.published.known.unconfirmed.no_hybrid.order(created_at: :desc)
  end

  def about
  end
end
