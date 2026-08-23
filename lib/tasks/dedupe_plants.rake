# frozen_string_literal: true
#
# `plants` jadvalidagi dublikat yozuvlarni birlashtiradi. Sabab: import
# tarixida `species_sci` faqat `.strip` bilan tozalangan edi — ichkaridagi
# ikkilangan bo'shliqlar va qiyshiq apostroflar (’ ‘ ʼ ´ vs ') tufayli bir
# xil o'simlik uchun bir nechta yozuv yaratilib qolgan (endi
# `import_plants.rake` bunday holatlarni normallashtiradi, lekin eski
# dublikatlar bazada qolgan).
#
# Sukut bo'yicha DRY RUN: nima qilinishi ekranga chiqariladi, bazaga HECH
# NARSA yozilmaydi. Haqiqiy o'zgarish uchun:
#   rails plants:dedupe APPLY=true
#
namespace :plants do
  desc "Bir xil o'simlikка tegishli dublikat Plant yozuvlarini birlashtirish (sukut: dry-run, APPLY=true — haqiqiy o'zgarish)"
  task dedupe: :environment do
    apply = ActiveModel::Type::Boolean.new.cast(ENV['APPLY'])

    puts(apply ? "APPLY=true — o'zgarishlar HAQIQATAN bazaga yoziladi." : "DRY RUN — hech narsa o'zgartirilmaydi (haqiqiy o'zgarish uchun APPLY=true bering).")
    puts '=' * 50

    # Bo'sh/nil species_sci'li yozuvlar (bo'lishi shart emas, lekin bazada
    # eskirgan/qo'lda yaratilgan yozuv uchrashi mumkin) bir-biriga
    # "dublikat" deb ATAB QO'YILMASIN — ular haqiqiy tur nomi emas,
    # normalize_species_sci(nil) => "" bo'lib hammasi bitta soxta guruhga
    # tushib qolardi. Shu sabab normallashtirilgandan keyin bo'sh chiqqan
    # kalitlar guruhlashdan chiqarib tashlanadi.
    groups = Plant.all.group_by { |p| normalize_species_sci(p.species_sci) }
                  .reject { |key, _plants| key.blank? }
                  .select { |_key, plants| plants.size > 1 }

    if groups.empty?
      puts "Dublikat topilmadi — hammasi toza."
      next
    end

    total_deleted = 0
    total_moved = 0

    ActiveRecord::Base.transaction do
      groups.each do |normalized_sci, plants|
        keeper = plants.max_by { |p|
          [
            PlantSighting.where(plant_id: p.id).count,
            p.attributes.except('id', 'created_at', 'updated_at').values.count(&:present?),
            -p.id
          ]
        }
        losers = plants - [ keeper ]

        moved = PlantSighting.where(plant_id: losers.map(&:id)).count

        puts "\nGuruh: \"#{normalized_sci}\""
        puts "  Qoladi:  id=#{keeper.id} (#{PlantSighting.where(plant_id: keeper.id).count} ta kuzatuv)"
        losers.each do |loser|
          puts "  O'chadi: id=#{loser.id} (#{PlantSighting.where(plant_id: loser.id).count} ta kuzatuv) — species_sci: #{loser.species_sci.inspect}"
        end
        puts "  Ko'chiriladigan kuzatuvlar: #{moved}"

        total_moved += moved
        total_deleted += losers.size

        next unless apply

        # `update_all` ATAYLAB ishlatilgan — faqat `plant_id` ustunini
        # yangilaydi, PlantSighting callback/validatsiyalarini chaqirmaydi.
        # Bu yerda aynan shu kerak: `status`, `photo_status` va h.k.
        # o'zgarmasligi, `notify_followers_of_approval`/
        # `enqueue_photo_processing` kabi after_commit'lar QAYTA
        # ISHGA TUSHMASLIGI shart (ular saved_change_to_status?/
        # saved_change_to_photo?ga bog'liq, plant_id o'zgarishiga emas —
        # `.update` ishlatilsa ham xato bo'lmasdi, lekin `update_all`
        # tezroq va niyatni aniqroq ifodalaydi).
        PlantSighting.where(plant_id: losers.map(&:id)).update_all(plant_id: keeper.id)
        Plant.where(id: losers.map(&:id)).delete_all
        keeper.update!(species_sci: normalized_sci)
      end

      raise ActiveRecord::Rollback unless apply
    end

    puts "\n#{'=' * 50}"
    puts 'Xulosa:'
    puts "  Dublikat guruhlar:      #{groups.size}"
    puts "  O'chadigan yozuvlar:    #{total_deleted}"
    puts "  Ko'chadigan kuzatuvlar: #{total_moved}"
    puts(apply ? "\nBajarildi — o'zgarishlar bazaga yozildi." : "\nBu DRY RUN edi — hech narsa o'zgarmadi. Haqiqiy o'zgarish uchun: rails plants:dedupe APPLY=true")
  end
end
