# frozen_string_literal: true
#
# Kuzatuv koordinatasini KO'RUVCHIGA qarab qaytaradigan YAGONA markaz —
# saytdagi BARCHA xaritalar (profil xaritasi, bosh sahifadagi xarita,
# kuzatuv sahifasidagi xarita) va joylashuv matni shu yerdan o'tadi.
#
# XAVFSIZLIK (2-ish/4-ishning ajralmas qismi): O'zbekistonda Qizil
# kitobdagi turlar (lola, eremurus, fritillariya) tijorat maqsadida
# yig'iladi — aniq koordinatani ochiq ko'rsatish brakonyerga manzil
# berish demak. iNaturalist buni "obscured coordinates" bilan hal qiladi,
# biz ham shunday qilamiz.
#
# Yaxlitlash SERVERDA bo'ladi — aniq koordinata JSON'ga UMUMAN tushmaydi
# (brauzerga yuborilgan har qanday ma'lumotni har kim ko'ra oladi). Bu
# eng muhim shart.
module SightingCoordinates
  module_function

  # 0.1 gradusga yaxlitlash — O'zbekiston kengligida taxminan 11 km
  # kenglikdagi katak.
  OBSCURED_PRECISION = 1

  # Qaytaradi:
  #   { lat: Float, lon: Float, obscured: Boolean }  — koordinata bor
  #   nil                                            — koordinata yo'q
  def for(sighting, viewer)
    return nil unless sighting.latitude.present? && sighting.longitude.present?

    if obscured_for?(sighting, viewer)
      {
        lat: sighting.latitude.to_f.round(OBSCURED_PRECISION),
        lon: sighting.longitude.to_f.round(OBSCURED_PRECISION),
        obscured: true
      }
    else
      { lat: sighting.latitude.to_f, lon: sighting.longitude.to_f, obscured: false }
    end
  end

  # To'rt holat:
  #   - tur Qizil kitobda EMAS             -> false (aniq koordinata)
  #   - Qizil kitob + ko'ruvchi = egasi    -> false (aniq)
  #   - Qizil kitob + ko'ruvchi = ekspert  -> false (aniq)
  #   - Qizil kitob + qolgan hamma (mehmon,
  #     boshqa foydalanuvchi)              -> true  (yaxlitlangan)
  def obscured_for?(sighting, viewer)
    return false unless sighting.coordinates_protected?
    return false if sighting.owner?(viewer)
    return false if viewer.try(:expert?)

    true
  end
end
