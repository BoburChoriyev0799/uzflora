# frozen_string_literal: true
#
# Kuzatuv joyi — VILOYAT darajasidagi strukturaviy ustun. Erkin matn
# `address` QOLADI (aniq joy uchun), viloyat esa alohida va strukturaviy.
#
#   region        — viloyat KALITI (ko'rinadigan nom EMAS — u tilga qarab
#                   o'zgaradi; kalit barqaror, RegionLookup::keys dan biri).
#   region_source — qiymat qayerdan: "user" (foydalanuvchi tanladi) /
#                   "auto" (koordinatadan RegionLookup) / "admin" (qo'lda).
#                   Ilmiy bazada qiymatning kelib chiqishi ko'rinib turishi
#                   shart (species_kaa_source kabi).
#
# `region` ga indeks — /plants dagi viloyat filtri korrelyatsiyalangan
# ichki so'rovsiz (JOIN yoki bitta EXISTS) ishlashi uchun ZARUR.
class AddRegionToPlantSightings < ActiveRecord::Migration[7.1]
  def change
    add_column :plant_sightings, :region, :string
    add_column :plant_sightings, :region_source, :string

    add_index :plant_sightings, :region
  end
end
