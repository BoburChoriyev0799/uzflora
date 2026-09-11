# frozen_string_literal: true
#
# Kuzatuvni to'liq tahrirlashda (1-ish) rasm almashtirilganda ilmiy audit
# izi — qachon almashtirilgani. Mavjud aniqlash (`identifications`)
# yozuvlari o'chirilmaydi (tarix sifatida qoladi); bu ustun ULARDAN
# ALOHIDA — "aniqlash tarixi" bilan "rasm qachon o'zgargani" boshqa-boshqa
# ma'lumot (semantik ajratish — moderation_note kabi boshqa maqsaddagi
# ustunga qo'shib yuborilmadi).
class AddPhotoReplacedAtToPlantSightings < ActiveRecord::Migration[7.1]
  def change
    add_column :plant_sightings, :photo_replaced_at, :datetime
  end
end
