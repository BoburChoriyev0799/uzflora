# frozen_string_literal: true
#
# Mavjud `plant_sightings.address` qiymatlaridagi ORTIQCHA BO'SHLIQNI
# tozalaydi: chetki bo'shliqlarni kesadi, ichki ketma-ket bo'shliqlarni
# bittaga siqadi, faqat bo'shliqdan iborat bo'lsa nil qiladi. Matn
# MAZMUNI (harflar, so'zlar, tartib) hech qachon o'zgarmaydi.
#
# YANGI saqlanadigan yozuvlar buni PlantSighting#normalize_address
# (before_save) orqali avtomatik oladi — bu task shu callback qo'shilishdan
# OLDIN yozilgan qatorlar uchun bir martalik tozalash.
#
# Standart holat — DRY RUN: nechta yozuv o'zgarishini va qanday
# o'zgarishini ko'rsatadi, BAZAGA TEGMAYDI.
#   rails plant_sightings:normalize_addresses
# Haqiqatan qo'llash uchun:
#   APPLY=true rails plant_sightings:normalize_addresses
namespace :plant_sightings do
  desc "Kuzatuv manzillaridagi ortiqcha bo'shliqni tozalash (DRY RUN; APPLY=true bilan qo'llaydi)"
  task normalize_addresses: :environment do
    apply = ENV['APPLY'] == 'true'

    changed = []
    PlantSighting.where.not(address: nil).find_each do |sighting|
      raw = sighting.address
      cleaned = raw.squish.presence
      next if cleaned == raw

      changed << [sighting.id, raw, cleaned]
    end

    puts apply ? '== QO\'LLASH REJIMI (APPLY=true) ==' : '== DRY RUN (bazaga tegilmaydi) =='
    puts "O'zgarishi kerak bo'lgan yozuvlar: #{changed.size}"

    changed.each do |id, raw, cleaned|
      puts "  ##{id}: #{raw.inspect} -> #{cleaned.inspect}"
    end

    if apply && changed.any?
      changed.each { |id, _raw, cleaned| PlantSighting.where(id: id).update_all(address: cleaned) }
      puts "Qo'llandi: #{changed.size} ta yozuv yangilandi."
    elsif changed.any?
      puts 'Qo\'llash uchun: APPLY=true rails plant_sightings:normalize_addresses'
    else
      puts 'Tozalash shart bo\'lgan yozuv yo\'q.'
    end
  end
end
