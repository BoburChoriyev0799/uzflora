# frozen_string_literal: true
module TextHelper
  # Matnning FAQAT birinchi harfini bosh harfga aylantiradi, qolgan
  # qismiga tegmaydi — masalan "annual, oil-bearing" -> "Annual,
  # oil-bearing" (vergul bilan ajratilgan ro'yxatdagi keyingi so'zlar
  # ATAYLAB kichik qoladi). Oddiy Ruby `String#capitalize` BUTUN
  # qolgan matnni ham kichik harfga tushiradi (mos emas) VA kirill
  # harflarida noto'g'ri ishlaydi — shu sabab faqat BIRINCHI belgiga,
  # Unicode-mos `mb_chars.upcase` orqali qo'llanadi.
  def capitalize_first(text)
    return text if text.blank?

    str = text.to_s
    first = str[0].mb_chars.upcase.to_s
    "#{first}#{str[1..]}"
  end
end
