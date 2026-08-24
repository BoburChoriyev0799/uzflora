# frozen_string_literal: true
#
# `species_sci` gacha faqat Rails darajasida (`validates :species_sci,
# presence: true`) himoyalangan edi — bazaning o'zida hech qanday cheklov
# yo'q edi. Bu ikkita real muammoga olib keldi:
#
#   1) Validatsiyani chetlab o'tuvchi yo'l (masalan `save(validate: false)`
#      yoki raw SQL) bilan BARCHA maydoni bo'sh "arvoh" Plant yozuvi paydo
#      bo'lgan edi — saytda bo'sh kartochka bo'lib ko'rinardi.
#   2) `species_sci` bo'yicha UNIQUE cheklov yo'qligi sababli 24 ta dublikat
#      yozuv to'planib qolgan edi (`plants:dedupe` orqali qo'lda birlashtirilgan).
#
# Bu migratsiya ikkalasini ham baza darajasida yopadi: NOT NULL + UNIQUE
# indeks. `up` DEPLOY vaqtida ishga tushishidan oldin ikkala shartni ham
# TEKSHIRADI — agar prod bazada bo'sh yoki dublikat `species_sci` bo'lsa,
# `PG::NotNullViolation`/`PG::UniqueViolation` kabi tushunarsiz xato o'rniga
# ANIQ o'zbekcha xabar bilan to'xtaydi (deploy baribir yiqiladi, lekin
# SABABI darhol ko'rinadi).
class AddNotNullAndUniqueToPlantsSpeciesSci < ActiveRecord::Migration[7.1]
  def up
    blank_count = select_value("SELECT COUNT(*) FROM plants WHERE species_sci IS NULL OR species_sci = ''").to_i
    if blank_count.positive?
      raise "MIGRATSIYA TO'XTATILDI: #{blank_count} ta Plant yozuvida species_sci NULL yoki bo'sh. " \
            "Avval shu yozuvlarni toping (`bin/rails runner 'Plant.where(species_sci: [nil, \"\"]).pluck(:id)'`) " \
            "va to'ldiring yoki o'chiring, keyin migratsiyani qayta ishga tushiring."
    end

    dup_rows = select_all(
      "SELECT species_sci, COUNT(*) AS c FROM plants GROUP BY species_sci HAVING COUNT(*) > 1 ORDER BY c DESC"
    )
    if dup_rows.any?
      dup_list = dup_rows.map { |r| "#{r['species_sci'].inspect} (#{r['c']} ta)" }.join(', ')
      raise "MIGRATSIYA TO'XTATILDI: quyidagi species_sci qiymatlari takrorlangan: #{dup_list}. " \
            "Avval `bin/rails plants:dedupe APPLY=true` orqali birlashtiring, keyin migratsiyani qayta ishga tushiring."
    end

    change_column_null :plants, :species_sci, false
    remove_index :plants, :species_sci
    add_index :plants, :species_sci, unique: true
  end

  def down
    remove_index :plants, :species_sci
    add_index :plants, :species_sci
    change_column_null :plants, :species_sci, true
  end
end
