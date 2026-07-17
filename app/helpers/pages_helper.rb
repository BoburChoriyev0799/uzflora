module PagesHelper

  # Ijtimoiy tarmoq (Telegram/Facebook/Twitter) preview'да ko'rinadigan
  # rasm — o'simlik/sayt logotipi bilan, birds.uz'дан meros qolgan qush
  # rasmi (fb/birds-fb-share.png) o'rniga.
  OG_IMAGE = 'fb/uzflora-share.png'

  def member_column_count(total_count)
    (total_count < 3) ? total_count : 3
  end

  def hide_body_backgroud?
    none_background_pages_options.detect { |options| current_page?(options) }
  end

  def og_image_url
    URI.join(root_url, image_path(OG_IMAGE))
  end

  def og_title
    I18n.t('layouts.og_title')
  end

  def og_description
    I18n.t('layouts.og_description')
  end

  def nav_bar_slogan
    if current_user.try(:birthday).try(:yday) == Date.today.yday
      "#{current_user.first_name}, #{I18n.t('shared.nav_bar_slogan.birth_day')}"
    elsif (Time.current.month == 12 && (30..31).include?(Time.current.day)) &&
        (Time.current.month == 1 && (1..2).include?(Time.current.day))
        controller_name == 'pages' &&
        action_name == 'index'
        I18n.t('shared.nav_bar_slogan.new_year')
    elsif Time.current.month == 7 && (14..18).include?(Time.current.day)
      I18n.t('shared.nav_bar_slogan.uzflora_birth_day')
    else
      I18n.t('shared.nav_bar_slogan.slogan')
    end
  end

  private
  def none_background_pages_options
    [ {controller: 'pages', action: 'index'} ]
  end
end
