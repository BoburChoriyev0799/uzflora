# frozen_string_literal: true
#
# BIR MARTALIK tekshiruv varaqasi (topshiriq 4-ish).
#
# `db/qoraqalpoq_bazada_yoq.csv` da POWO tan oladigan, lekin bazada YO'Q
# turlar bor. Ular O'zbekistonda HAQIQATAN uchraydimi — POWO jonli API'ning
# TARQALISH (TDWG) ma'lumotidan aniqlaymiz va CSV chiqaramiz.
#
#   tmp/bazada_yoq_tekshiruv.csv:
#     eski_nom, powo_qabul_qilgan_nom, powo_id, oila,
#     ozbekistonda_bormi (HA/YO'Q/NOMA'LUM), tdwg_kodlari,
#     tabiiy_tarqalish, izoh
#
# O'ZBEKISTON TDWG L3 KODI: UZB
#   - POWO tarqalishida (natives/introduced) UZB bo'lsa -> HA
#   - tarqalish ma'lumoti bor, lekin UZB yo'q -> YO'Q
#   - tarqalish ma'lumoti umuman yo'q (yoki API xato) -> NOMA'LUM
#
# QAT'IY: HECH QANDAY TURNI BAZAGA QO'SHMAYDI. Faqat tekshiruv varaqasi.
# So'rovlar orasида kutish. Ma'lumot topilmasa "NOMA'LUM", taxmin yo'q.
#
#   rails plants:check_missing_species_distribution
#   rails plants:check_missing_species_distribution DELAY=2
require 'csv'
# QoraqalpoqPowoApi moduli lib/tasks/qoraqalpoq_powo_api.rake da (POWO
# HTTP + qayta urinish mantig'i). Rake barcha .rake fayllarni har qanday
# task ISHGA TUSHISHIDAN OLDIN yuklaydi, shuning uchun `require` shart emas —
# task ishlaganda modul allaqachon aniqlangan bo'ladi.

module CheckMissingDistribution
  SOURCE_PATH = Rails.root.join('db', 'qoraqalpoq_bazada_yoq.csv')
  OUT_PATH = Rails.root.join('tmp', 'bazada_yoq_tekshiruv.csv')
  OUT_HEADERS = %w[
    eski_nom powo_qabul_qilgan_nom powo_id oila ozbekistonda_bormi
    tdwg_kodlari tabiiy_tarqalish izoh
  ].freeze
  # `/api/2/taxon/<id>?fields=distribution` Cloudflare 403 beradi (fields
  # parametri challenge'ni ishga tushiradi). `/api/1/taxon/<id>` esa
  # `distributions` massivini to'g'ridan-to'g'ri qaytaradi (parametrsiz).
  TAXON_URL = 'https://powo.science.kew.org/api/1/taxon'

  module_function

  # POWO taxon endpoint'idan tarqalish -> { uzb:, tdwg: [..], natives_text:, note: }
  def distribution_for(powo_id, delay:)
    return { uzb: 'NOMA\'LUM', note: 'powo_id yo\'q' } if powo_id.blank?

    status, data = QoraqalpoqPowoApi.http_get_json("#{TAXON_URL}/#{powo_id}")
    return { uzb: 'NOMA\'LUM', note: "API xato: #{data}" } if status != :ok

    dists = Array(data['distributions'])
    return { uzb: 'NOMA\'LUM', note: 'tarqalish ma\'lumoti yo\'q' } if dists.empty?

    l3 = dists.select { |e| e['tdwgLevel'] == 3 }
    l3 = dists if l3.empty?
    tdwg = l3.map { |e| e['tdwgCode'] }.compact.uniq.sort
    uzb_rows = l3.select { |e| e['tdwgCode'] == 'UZB' }
    uzb_native = uzb_rows.any? { |e| e['establishment'].to_s.casecmp('native').zero? }

    uzb = uzb_rows.any? ? 'HA' : 'YO\'Q'
    note = uzb_rows.any? && !uzb_native ? 'UZB: introdutsent/noaniq' : nil
    natives_text = l3.select { |e| e['establishment'].to_s.casecmp('native').zero? }
                     .map { |e| e['name'] }.compact.first(20).join(', ')
    { uzb: uzb, tdwg: tdwg, natives_text: natives_text, note: note }
  end
end

namespace :plants do
  desc 'db/qoraqalpoq_bazada_yoq.csv turlarini POWO tarqalish (TDWG/UZB) bo`yicha tekshirish'
  task check_missing_species_distribution: :environment do
    m = CheckMissingDistribution
    delay = (ENV['DELAY'].presence || 1.5).to_f

    unless File.exist?(m::SOURCE_PATH)
      abort "XATO: #{m::SOURCE_PATH} topilmadi."
    end
    unless defined?(QoraqalpoqPowoApi)
      abort 'XATO: lib/tasks/qoraqalpoq_powo_api.rake kerak (HTTP yordamchisi).'
    end

    src = CSV.read(m::SOURCE_PATH, headers: true).select { |r| r['powo_qabul_qilgan_nom'].to_s.strip.present? }
    puts "Tekshiriladi: #{src.size} tur (POWO yechgan, bazada yo'q). Kutish: #{delay}s."
    puts '=' * 64

    # Oila — bazadagi accepted_family dan (bor bo'lsa) yoki bo'sh.
    fam_by_name = Plant.where(accepted_name: src.map { |r| r['powo_qabul_qilgan_nom'] })
                       .pluck(:accepted_name, :accepted_family).to_h

    out = []
    counts = Hash.new(0)
    src.each_with_index do |r, i|
      name = r['powo_qabul_qilgan_nom'].to_s.strip
      print "  [#{i + 1}/#{src.size}] #{name} ... "
      d = m.distribution_for(r['powo_id'].to_s.strip, delay: delay)
      counts[d[:uzb]] += 1
      puts d[:uzb] + (d[:note] ? " (#{d[:note]})" : '')
      out << [
        r['eski_nom'], name, r['powo_id'], fam_by_name[name],
        d[:uzb], Array(d[:tdwg]).join(' '), d[:natives_text], d[:note]
      ]
      sleep delay unless i == src.size - 1
    end

    FileUtils.mkdir_p(File.dirname(m::OUT_PATH))
    CSV.open(m::OUT_PATH, 'w', encoding: 'UTF-8') do |csv|
      csv << m::OUT_HEADERS
      out.each { |row| csv << row }
    end

    puts "\n#{'=' * 64}"
    puts "#{m::OUT_PATH} yozildi: #{out.size} qator."
    puts "  O'zbekistonda bor (HA):    #{counts['HA']}"
    puts "  O'zbekistonda yo'q (YO'Q): #{counts["YO'Q"]}"
    puts "  Noma'lum:                  #{counts["NOMA'LUM"]}"
    puts "\nDIQQAT: hech qanday tur bazaga QO'SHILMADI. Qo'shish qarorini Bobur qabul qiladi."
  end
end
