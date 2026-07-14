# frozen_string_literal: true
#
# O'simliklarni CSV faylidan bazaga import qiladi.
#
# Ishga tushirish (Claude Code / terminalda, loyiha ildizida):
#   rails plants:import
#
# CSV fayli `db/plants.csv` da bo'lishi kerak.
# Qayta ishga tushirilsa, mavjud yozuvlarni species_id bo'yicha yangilaydi
# (takror yaratmaydi).
#
require 'csv'

namespace :plants do
  desc 'CSV faylidan o\'simliklarni bazaga import qilish'
  task import: :environment do
    path = Rails.root.join('db', 'plants.csv')
    unless File.exist?(path)
      puts "XATO: #{path} topilmadi. plants.csv ni db/ papkasiga joylang."
      next
    end

    created = 0
    updated = 0
    row_num = 0

    CSV.foreach(path, headers: true) do |row|
      row_num += 1
      attrs = row.to_h

      # 'id' ustunini olib tashlaymiz — Rails o'zi beradi
      attrs.delete('id')

      # Bo'sh (nil) qiymatlarni tozalaymiz
      attrs.each { |k, v| attrs[k] = nil if v.nil? || v.to_s.strip.empty? }

      # red_book ustunini boolean qilamiz
      attrs['red_book'] = %w[true True TRUE 1].include?(attrs['red_book'].to_s)

      sid = attrs['species_id']

      plant =
        if sid.present?
          Plant.find_or_initialize_by(species_id: sid)
        else
          Plant.find_or_initialize_by(species_sci: attrs['species_sci'])
        end

      was_new = plant.new_record?
      plant.assign_attributes(attrs)

      if plant.save
        was_new ? (created += 1) : (updated += 1)
      else
        puts "Qator #{row_num} saqlanmadi: #{plant.errors.full_messages.join(', ')}"
      end

      puts "  ...#{row_num} qator ishlandi" if (row_num % 500).zero?
    end

    puts '=' * 50
    puts "Import tugadi!"
    puts "  Yangi qo'shilgan: #{created}"
    puts "  Yangilangan:      #{updated}"
    puts "  Jami bazada:      #{Plant.count}"
    puts "  Qizil kitobda:    #{Plant.where(red_book: true).count}"
  end

  desc 'Barcha o\'simliklarni bazadan o\'chirish (ehtiyot bo\'ling!)'
  task clear: :environment do
    count = Plant.count
    Plant.delete_all
    puts "#{count} ta o'simlik o'chirildi."
  end
end
