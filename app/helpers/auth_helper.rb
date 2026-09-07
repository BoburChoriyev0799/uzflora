# frozen_string_literal: true

# Kirish / ro'yxatdan o'tish sahifalari uchun inline SVG ikonkalar —
# tashqi shrift kutubxonasi (boxicons CDN) yuklanmaydi.
module AuthHelper
  AUTH_ICONS = {
    mail: '<path d="M4 4h16a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1z"/><path d="m3 6 9 7 9-7"/>',
    lock: '<rect x="4" y="10" width="16" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>',
    user: '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
    facebook: '<path d="M13.397 20.997v-8.196h2.765l.411-3.209h-3.176V7.548c0-.926.258-1.56 1.587-1.56h1.684V3.127A22.336 22.336 0 0 0 14.201 3c-2.444 0-4.122 1.492-4.122 4.231v2.355H7.332v3.209h2.753v8.202z"/>'
  }.freeze

  def auth_icon(name)
    body = AUTH_ICONS.fetch(name.to_sym)
    stroke = name.to_sym == :facebook ? 'none' : 'currentColor'
    fill = name.to_sym == :facebook ? 'currentColor' : 'none'
    content = <<~SVG.html_safe
      <svg viewBox="0 0 24 24" fill="#{fill}" stroke="#{stroke}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">#{body}</svg>
    SVG
    content
  end
end
