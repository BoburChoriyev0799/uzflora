# frozen_string_literal: true
#
# 2-ish: kuzatuv rasmini yuklab olishda fayl nomi ILMIY NOM bilan —
# "Genus_species_YYYY-MM-DD_uzflora-<id>.jpg" (masalan
# "Capparis_spinosa_2026-08-24_uzflora-113.jpg"). Tur aniqlanmagan bo'lsa
# "aniqlanmagan_...".
#
# XAVFSIZLIK: natija QAT'IY [A-Za-z0-9_-.] to'plamiga cheklanadi (allowlist,
# denylist EMAS) — "/", "\", ".." va boshqa xavfli belgilar TARKIBIDA
# BO'LISHI FIZIK JIHATDAN MUMKIN EMAS, ular nima bo'lishidan qat'i nazar.
module SightingDownloadFilename
  UNKNOWN_LABEL = 'aniqlanmagan'
  DEFAULT_EXTENSION = 'jpg'
  ALLOWED_EXTENSIONS = %w[jpg jpeg png].freeze

  module_function

  def for(sighting)
    "#{binomial_part(sighting.plant)}_#{date_part(sighting)}_uzflora-#{sighting.id}.#{extension_for(sighting)}"
  end

  # "Genus epithet" — muallif qisqartmasi va infratur darajasi (var./
  # subsp.) YO'Q. `accepted_name` (POWO moslashtirilgan, muallifsiz)
  # ustuvor; bo'lmasa xom `species_sci` (bunda ham faqat dastlabki 1-2
  # so'z olinadi — muallif qismi shu bilan tabiiy ravishda tashlab
  # ketiladi). Duragay belgisi ("×"/"x" ikkinchi so'zda) hisobga olinadi —
  # `Plant#external_search_name` dagi bilan bir xil qoida.
  def binomial_part(plant)
    return UNKNOWN_LABEL if plant.blank?

    raw = plant.accepted_name.presence || plant.species_sci
    return UNKNOWN_LABEL if raw.blank?

    words = raw.to_s.split(/\s+/)
    take = words[1]&.match?(/\A[x×]\z/i) ? 3 : 2
    sanitize(words.first(take).join('_'))
  end

  def date_part(sighting)
    (sighting.timestamp || sighting.created_at).strftime('%Y-%m-%d')
  end

  def extension_for(sighting)
    ext = sighting.photo.file&.extension.to_s.downcase
    ALLOWED_EXTENSIONS.include?(ext) ? ext : DEFAULT_EXTENSION
  end

  # ASCII'ga keltiradi (diakritika/kirill translit), apostrof va boshqa
  # tinish belgilarini olib tashlaydi, "×" ni "x" ga almashtiradi, probelni
  # pastki chiziqqa. Natijada FAQAT harf/raqam/pastki chiziq/chiziqcha
  # qoladi ("caput-medusae" kabi chiziqcha bilan yozilgan epitetlar shu
  # bilan o'qilishi mumkin bo'lib qoladi) — boshqa HAMMA narsa (jumladan
  # "/", "\", "..", bo'shliq) kesib tashlanadi.
  def sanitize(str)
    ascii = ActiveSupport::Inflector.transliterate(str.to_s.tr('×', 'x').tr(' ', '_'))
    cleaned = ascii.gsub(/[^A-Za-z0-9_-]/, '')
    cleaned.presence || UNKNOWN_LABEL
  end
end
