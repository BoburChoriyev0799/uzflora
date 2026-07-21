module ApplicationHelper

  # Navbar til-tanlash dropdown'i uchun — Unicode bayroq emoji ba'zi
  # OS/brauzer (jumladan Windows'ning ko'p qismi) kombinatsiyasida
  # umuman ko'rinmadi (rangli emoji shrifti yo'q), shuning uchun
  # to'g'ridan-to'g'ri inline SVG'ga o'tkazildi — tashqi fayl/URL'ga
  # bog'liq emas, har doim bir xil rangli ko'rinadi.
  LOCALE_FLAG_SVGS = {
    uz: <<~SVG.freeze,
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 14" class="navbar-flag-svg" aria-hidden="true">
        <rect width="20" height="14" fill="#1eb53a"/>
        <rect width="20" height="4.3" fill="#0099b5"/>
        <rect y="4.3" width="20" height="0.55" fill="#ce1126"/>
        <rect y="4.85" width="20" height="4.3" fill="#fff"/>
        <rect y="9.15" width="20" height="0.55" fill="#ce1126"/>
        <circle cx="3.3" cy="2.15" r="1.35" fill="#fff"/>
        <circle cx="3.85" cy="2.15" r="1.1" fill="#0099b5"/>
      </svg>
    SVG
    ru: <<~SVG.freeze,
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 14" class="navbar-flag-svg" aria-hidden="true">
        <rect width="20" height="14" fill="#fff"/>
        <rect y="4.67" width="20" height="4.67" fill="#0039a6"/>
        <rect y="9.33" width="20" height="4.67" fill="#d52b1e"/>
      </svg>
    SVG
    en: <<~SVG.freeze,
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 14" class="navbar-flag-svg" aria-hidden="true">
        <rect width="20" height="14" fill="#00247d"/>
        <path d="M0,0 L20,14 M20,0 L0,14" stroke="#fff" stroke-width="2.8"/>
        <path d="M0,0 L20,14 M20,0 L0,14" stroke="#cf142b" stroke-width="1"/>
        <path d="M10,0 V14 M0,7 H20" stroke="#fff" stroke-width="4.6"/>
        <path d="M10,0 V14 M0,7 H20" stroke="#cf142b" stroke-width="2.6"/>
      </svg>
    SVG
  }.freeze

  def locale_flag(locale)
    (LOCALE_FLAG_SVGS[locale.to_sym] || '').html_safe
  end

  def ldate(dt, hash = {})
    dt ? l(dt, hash) : nil
  end

  def nav_link_to(name = nil, options = nil, html_options = nil, &block)
    is_active = request.path.start_with?(url_for(options)) ? true : false

    li_class = []
    li_class.append(html_options.delete(:li_class)) if html_options
    li_class.append(:active) if is_active

    content_tag :li, class: li_class.presence do
      link_to(name, options, html_options, &block)
    end
  end

  def date_format(date)
    return '' unless date.present?
    date.strftime('%d/%m/%Y')
  end

  def datetime_format(date)
    return '' unless date.present?
    date.strftime('%d/%m/%Y %H:%M')
  end

  #TODO: add method to cut text without word breaking
  def short_comment_text(comment, max_size)
    if comment.text.size > max_size
      return comment.text.to_s.slice(0, max_size)
    else
      return comment.text
    end
  end

  def short_comment_text_dots(comment, max_size)
    text = short_comment_text(comment, max_size)
    comment.text.size > text.length ? text + '...' : text
  end

  # Ijtimoiy tarmoq/aloqa tugmasi — brend rangida doira ichida belgi
  # (Bootstrap glyphicon yoki qisqa matn, masalan "f"/"in"/"@") + nom.
  # about.html.haml va big_years/index.html.haml'да ishlatiladi.
  def social_link(label, url, glyph: nil, text_icon: nil, color: '#7cb342', **html_options)
    icon = if text_icon.present?
             content_tag(:span, text_icon, class: 'contact-icon-text')
           else
             content_tag(:span, '', class: "glyphicon glyphicon-#{glyph}")
           end
    badge = content_tag(:span, icon, class: 'contact-icon', style: "background-color:#{color}")
    link_to safe_join([badge, label]), url, { class: 'contact-link' }.merge(html_options)
  end
end
