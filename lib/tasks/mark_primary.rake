# frozen_string_literal: true
#
# POWO/WCVP taksonomik solishtiruv natijasida bir nechta `plants` yozuvi
# BITTA xil `accepted_name`ga tenglashtirilishi mumkin (masalan
# "Merendera robusta" va "Merendera hissarica" — ikkalasi ham
# "Colchicum robustum"). Bu TEXNIK dublikat EMAS — har birining o'z
# o'zbekcha/ruscha nomi, Qizil kitob holati va rasmlari bor, shuning
# uchun HECH QANDAY yozuv o'chirilmaydi yoki birlashtirilmaydi.
#
# Bu task shunchaki har guruhda BITTA "primary" (ro'yxatda/qidiruvda
# ko'rinadigan) yozuvni belgilaydi — qolganlari bazada, o'z sahifasida
# turaveradi (havola orqali ochiladi), faqat ro'yxatda alohida
# kartochka bo'lib chiqmaydi (ko'rish: PlantsController#index,
# `.where(primary_record: true)`).
#
# Ishga tushirish:
#   rails plants:mark_primary            # DRY RUN — hech narsa yozilmaydi
#   rails plants:mark_primary APPLY=true # haqiqiy yozish
#
# `plants:powo_apply APPLY=true` oxirida AVTOMATIK chaqiriladi (har POWO
# yangilanishidan keyin guruhlar qayta hisoblanishi kerak — accepted_name
# o'zgarishi guruh tarkibini o'zgartirishi mumkin).
require 'csv'
require 'set'

EXCEPTIONS_PATH = Rails.root.join('db', 'duplikat_istisnolar.csv')

# Qizil kitob — huquqiy hujjat: agar BITTA guruhda (accepted_name)
# IKKITA (yoki undan ko'p) MUSTAQIL Qizil kitob turi tasodifan
# birlashtirilgan bo'lsa (masalan Tulipa ingens VA Tulipa tubergeniana
# — ikkalasi ham Qizil kitobda, lekin POWO ularni bitta "Tulipa
# ingens"ga tenglashtirgan), ikkalasi ham o'z alohida kartochkasida
# ko'rinishi SHART — birortasini yashirib qo'yib bo'lmaydi (2026-08-28,
# Bobur bilan kelishilgan: 314 talik rasmiy ro'yxat DOIMIY hisoblanadi,
# faqat shu — "guruhda 2+ Qizil kitob a'zosi" — holatigagina tegishli;
# guruhda BITTA Qizil kitob a'zosi, BOSHQASI Qizil kitob BO'LMAGAN bo'lsa
# — bu yerga KIRMAYDI, o'sha guruh o'zgarishsiz, birlashgan holicha
# qoladi — `group_red_book` ustuni orqali filtrga baribir tushadi, faqat
# ALOHIDA kartochka bo'lib ajralmaydi; ro'yxat rasmiy Qizil kitob
# yangilanganda qayta ko'rib chiqiladi).

# "To'ldirilgan maydonlar" hisobi uchun — faqat foydalanuvchiga ko'rinadigan
# tavsif maydonlari (taksonomiya ustunlari BU YERDA emas: guruh a'zolari
# deyarli har doim bir xil oila/turkumga tegishli bo'lgani uchun ular
# orasida farqlash uchun foydasiz).
PRIMARY_CONTENT_FIELDS = %w[
  species_ru species_uz plantarium_url life_form usage
  range_world range_central_asia range_uzbekistan endemism protected_areas
  life_form_ru life_form_en habitat_place_ru habitat_place_en
  usage_ru usage_en habitat_env_ru habitat_env_en
  range_world_ru range_world_en range_central_asia_ru range_central_asia_en
  range_uzbekistan_ru range_uzbekistan_en habitat_env habitat_place
].freeze

def filled_score(plant)
  score = PRIMARY_CONTENT_FIELDS.count { |f| plant.public_send(f).present? }
  score += 1 if plant.red_book?
  score
end

def load_exceptions
  return Set.new unless File.exist?(EXCEPTIONS_PATH)

  CSV.read(EXCEPTIONS_PATH, headers: true).map { |row| row['species_sci'].to_s.strip }.reject(&:empty?).to_set
end

namespace :plants do
  desc "Bir xil accepted_name'ga tushgan yozuvlar orasidan har guruh uchun 'primary' (ro'yxatda ko'rinadigan) yozuvni belgilash"
  task mark_primary: :environment do
    apply = ActiveModel::Type::Boolean.new.cast(ENV['APPLY'])
    puts(apply ? "APPLY=true — o'zgarishlar HAQIQATAN bazaga yoziladi." : "DRY RUN — hech narsa o'zgartirilmaydi (haqiqiy yozish uchun APPLY=true bering).")
    puts '=' * 60

    exceptions = load_exceptions
    puts "Istisnolar (db/duplikat_istisnolar.csv): #{exceptions.size} ta nom"

    approved_counts = PlantSighting.where(status: 'approved').group(:plant_id).count
    puts "Tasdiqlangan kuzatuvlar bo'yicha hisob tayyor (#{approved_counts.size} ta o'simlikka tegishli)."

    all_plants = Plant.all.to_a
    puts "Jami o'simliklar: #{all_plants.size}"

    desired = {} # id => true/false
    reasons = {} # id => qisqa izoh (log uchun)

    no_accepted, with_accepted = all_plants.partition { |p| p.accepted_name.blank? }
    no_accepted.each { |p| desired[p.id] = true }

    groups = with_accepted.group_by(&:accepted_name)
    single_groups = groups.select { |_, members| members.size == 1 }
    multi_groups = groups.reject { |_, members| members.size == 1 }

    # --- group_red_book: "guruhning BIROR a'zosi Qizil kitobda bo'lsa,
    # BARCHASI (jumladan yashiringan a'zolar orqasidagi primary) Qizil
    # kitob filtriga tushsin". `red_book`ning O'ZIGA tegilmaydi — bu
    # FAQAT filtrlash uchun hisoblab chiqilgan qo'shimcha ustun. Bu yerda
    # ATAYLAB `groups` (single + multi, HAMMASI) ishlatiladi, "effective
    # members" (istisnolarni hisobga oluvchi, faqat ko'rinish uchun
    # ishlatiladigan) mantiqqa BOG'LIQ EMAS — Qizil kitob filtri
    # taksonomik guruhning O'ZIGA tegishli haqiqat, ko'rinish qoidalariga
    # emas.
    desired_group_red_book = {}
    no_accepted.each { |p| desired_group_red_book[p.id] = p.red_book? }
    groups.each do |_, members|
      any_red = members.any?(&:red_book?)
      members.each { |m| desired_group_red_book[m.id] = any_red }
    end

    single_groups.each_value { |members| desired[members.first.id] = true }

    multi_groups.each do |accepted_name, members|
      accepted_status_members = members.select { |m| m.wcvp_status == 'Accepted' }

      primary =
        if accepted_status_members.size == 1
          accepted_status_members.first
        else
          members.max_by { |m| [ approved_counts[m.id] || 0, filled_score(m), -m.id ] }
        end

      members.each { |m| desired[m.id] = (m.id == primary.id) }
    end

    # --- Qizil kitob majburiy primary: FAQAT guruhda 2+ MUSTAQIL Qizil
    # kitob a'zosi bo'lgan holatda (yuqoridagi izohga qarang) — o'sha
    # a'zolarning HAMMASI majburan primary=true qilinadi, guruhning
    # "asosiy" (WCVP-Accepted/eng ko'p ma'lumotli) a'zosi sifatida
    # tanlanmagan bo'lsa ham. Natijada guruhda bir nechta primary=true
    # yozuv qolishi MUMKIN (xuddi `db/duplikat_istisnolar.csv`
    # istisnolari kabi) — bu ATAYLAB shunday, ko'rinish mantig'i
    # (PlantsHelper#plant_card_group_info) buni allaqachon to'g'ri
    # boshqaradi (har biri o'zining xom nomi bilan, sinonim qatorisiz,
    # mustaqil kartochka).
    red_book_forced_ids = []
    groups.each do |_, members|
      red_book_members = members.select(&:red_book?)
      next unless red_book_members.size > 1

      red_book_members.each do |p|
        next unless desired[p.id] == false

        desired[p.id] = true
        red_book_forced_ids << p.id
      end
    end

    # --- group_has_photo: "shu yozuvning o'zida YOKI accepted_name
    # guruhidagi biror HAQIQATAN YASHIRINGAN (yangi primary_record=false)
    # a'zosida tasdiqlangan+nashr qilingan kuzatuv bo'lsa" — ro'yxatdagi
    # "rasmli o'simliklar oldinda" tartibi endi shu OLDINDAN HISOBLANGAN
    # ustundan foydalanadi (ko'rish: `PlantsController#index`). Kundalik
    # (bitta kuzatuv o'zgarganda) yangilanish `Plant.refresh_group_has_
    # photo!` orqali (`PlantSighting`dagi callback chaqiradi) — bu yerda
    # esa TO'LIQ qayta hisoblash (masalan POWO guruhlari o'zgarganda).
    # Yuqorida hisoblangan `desired` (YANGI primary_record maqsadi)
    # ishlatiladi, joriy bazadagi eski qiymat EMAS — shu bir xil
    # yugurishda ikkalasi ham izchil bo'lishi uchun.
    has_photo_ids = PlantSighting.published.approved.distinct.pluck(:plant_id).to_set
    puts "\nTasdiqlangan+nashr qilingan kuzatuvi bor o'simliklar: #{has_photo_ids.size}"

    desired_group_has_photo = {}
    no_accepted.each { |p| desired_group_has_photo[p.id] = has_photo_ids.include?(p.id) }
    groups.each do |_, members|
      members.each do |m|
        desired_group_has_photo[m.id] = has_photo_ids.include?(m.id) ||
          members.any? { |sibling| !desired[sibling.id] && has_photo_ids.include?(sibling.id) }
      end
    end

    # --- Istisnolar: doim primary_record = true, guruhdagi boshqa
    # tanlovga QARAMASDAN. Guruhda shu tufayli bir nechta primary=true
    # yozuv qolishi MUMKIN (masalan Malus domestica ham, Malus sieversii
    # ham) — bu ATAYLAB shunday: istisno "bu turni hech qachon
    # yashirmaslikni" bildiradi, u guruhning "yagona vakili" bo'lishi
    # SHART emas.
    exception_ids = []
    if exceptions.any?
      Plant.where(species_sci: exceptions.to_a).find_each do |p|
        desired[p.id] = true
        exception_ids << p.id
      end
      found_names = Plant.where(species_sci: exceptions.to_a).pluck(:species_sci).to_set
      (exceptions - found_names).each do |missing|
        puts "OGOHLANTIRISH: istisno ro'yxatidagi \"#{missing}\" bazada topilmadi (imlo xatosi bo'lishi mumkin)."
      end
    end

    current_by_id = all_plants.index_by(&:id)
    to_true = desired.select { |id, v| v == true && !current_by_id[id].primary_record }.keys
    to_false = desired.select { |id, v| v == false && current_by_id[id].primary_record }.keys

    group_red_book_to_true = desired_group_red_book.select { |id, v| v == true && !current_by_id[id].group_red_book }.keys
    group_red_book_to_false = desired_group_red_book.select { |id, v| v == false && current_by_id[id].group_red_book }.keys

    group_has_photo_to_true = desired_group_has_photo.select { |id, v| v == true && !current_by_id[id].group_has_photo }.keys
    group_has_photo_to_false = desired_group_has_photo.select { |id, v| v == false && current_by_id[id].group_has_photo }.keys

    puts "\n#{'=' * 60}"
    puts "Guruhlar (accepted_name bo'yicha, bittadan ko'p a'zoli): #{multi_groups.size}"
    puts "Shu guruhlardagi jami yozuvlar: #{multi_groups.values.sum(&:size)}"
    puts "Qizil kitob sababli majburan primary=true qilingan: #{red_book_forced_ids.size}"
    puts "Istisno sifatida majburan primary=true qilingan: #{exception_ids.size}"
    puts "\nO'zgaradi: primary_record TRUE -> FALSE: #{to_false.size}"
    puts "O'zgaradi: primary_record FALSE -> TRUE: #{to_true.size}"
    puts "Yakunda primary_record=false bo'ladigan jami: #{desired.count { |_, v| v == false }}"
    puts "Yakunda primary_record=true bo'ladigan jami: #{desired.count { |_, v| v == true }}"

    puts "\nO'zgaradi: group_red_book FALSE -> TRUE: #{group_red_book_to_true.size}"
    puts "O'zgaradi: group_red_book TRUE -> FALSE: #{group_red_book_to_false.size}"
    puts "Yakunda group_red_book=true bo'ladigan jami: #{desired_group_red_book.count { |_, v| v == true }}"
    puts "  (shundan red_book=true bo'lgan haqiqiy soni: #{all_plants.count(&:red_book?)})"

    puts "\nO'zgaradi: group_has_photo FALSE -> TRUE: #{group_has_photo_to_true.size}"
    puts "O'zgaradi: group_has_photo TRUE -> FALSE: #{group_has_photo_to_false.size}"
    puts "Yakunda group_has_photo=true bo'ladigan jami: #{desired_group_has_photo.count { |_, v| v == true }}"

    if apply
      ActiveRecord::Base.transaction do
        Plant.where(id: to_false).update_all(primary_record: false) if to_false.any?
        Plant.where(id: to_true).update_all(primary_record: true) if to_true.any?
        Plant.where(id: group_red_book_to_false).update_all(group_red_book: false) if group_red_book_to_false.any?
        Plant.where(id: group_red_book_to_true).update_all(group_red_book: true) if group_red_book_to_true.any?
        Plant.where(id: group_has_photo_to_false).update_all(group_has_photo: false) if group_has_photo_to_false.any?
        Plant.where(id: group_has_photo_to_true).update_all(group_has_photo: true) if group_has_photo_to_true.any?
      end
      puts "\nBajarildi."
    else
      puts "\nBu DRY RUN edi — hech narsa o'zgarmadi. Haqiqiy yozish uchun: rails plants:mark_primary APPLY=true"
    end
  end
end
