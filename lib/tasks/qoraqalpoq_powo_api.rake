# frozen_string_literal: true
#
# BIR MARTALIK tekshiruv: `plants:import_qoraqalpoq` da TOPILMADI bo'lib
# qolgan (madaniy EMAS) nomlarni POWO JONLI REST API orqali yechadi.
#
# NEGA ALOHIDA / JONLI API: `import_qoraqalpoq` ning 4-bosqichi WCVP
# faylidan (db/external/wcvp_names.csv) ANIQ nom mosligi bilan ishlaydi —
# muallif/imlo farqi bo'lgan eski nomlarni o'tkazib yuborishi mumkin.
# POWO jonli API kengroq qidiradi. Bu GBIF solishtiruvidan keyingi
# IKKINCHI mustaqil tekshiruv — bazadagi haqiqiy bo'shliqlarni ko'rsatadi.
#
# NATIJA:
#   db/qoraqalpoq_bazada_yoq.csv  (eski_nom, powo_qabul_qilgan_nom, powo_id, holat)
#     holat: "POWO: qabul qilingan nom" / "POWO: sinonim" /
#            "POWO'da topilmadi" / "POWO API xato: ..."
#   Yechilgan VA bazada bor nomlar -> db/qoraqalpoq_nomlari_hal_qilingan.csv
#     ga qo'shiladi (import shu fayldan o'qiydi).
#
# TAXMIN QILINMAYDI — API nima qaytarsa, shu yoziladi.
#
#   rails plants:qoraqalpoq_powo_api           # tekshiradi, fayllarni yozadi
#   rails plants:qoraqalpoq_powo_api DELAY=2   # so'rovlar orasidagi kutish (s)
#
# DIQQAT: POWO API Cloudflare himoyasi ostida — ba'zi muhitlardan (masalan
# brauzersiz WSL) 403 bilan bloklanadi. Bunday holda task birinchi so'rovdayoq
# to'xtaydi va xabar beradi; boshqa muhitdan yugurtiring.
require 'csv'
require 'net/http'
require 'json'
require Rails.root.join('lib', 'powo', 'matcher')

module QoraqalpoqPowoApi
  BAZADA_YOQ_PATH = Rails.root.join('db', 'qoraqalpoq_bazada_yoq.csv')
  BAZADA_YOQ_HEADERS = %w[eski_nom powo_qabul_qilgan_nom powo_id holat].freeze
  SEARCH_URL = 'https://powo.science.kew.org/api/2/search'
  TAXON_URL = 'https://powo.science.kew.org/api/2/taxon'
  USER_AGENT = 'uzflora.uz taxonomy check (one-off; contact via github.com/BoburChoriyev0799/uzflora)'

  module_function

  # POWO Cloudflare himoyasi ostida — 403 vaqti-vaqti bilan qaytadi.
  # Har so'rovni 3 martagacha, orasida uzayib boruvchi kutish bilan sinaydi.
  def http_get_json(url, attempts: 3)
    last = nil
    attempts.times do |n|
      sleep(2 * n) if n.positive?
      last = http_get_json_once(url)
      return last if last[0] == :ok
      return last unless last[1].to_s.include?('403') || last[1].to_s.include?('Cloudflare')
    end
    last
  end

  def http_get_json_once(url)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 25
    req = Net::HTTP::Get.new(uri)
    req['User-Agent'] = USER_AGENT
    req['Accept'] = 'application/json'
    res = http.request(req)

    return [ :error, "HTTP #{res.code}" ] unless res.is_a?(Net::HTTPSuccess)

    body = res.body.to_s
    return [ :error, 'Cloudflare challenge (brauzer kerak)' ] if body.lstrip.start_with?('<!DOCTYPE', '<html')

    [ :ok, JSON.parse(body) ]
  rescue JSON::ParserError
    [ :error, 'JSON emas javob' ]
  rescue StandardError => e
    [ :error, "#{e.class}: #{e.message}" ]
  end

  # "Turkum epitet [infra]" — muallifsiz qidiruv nomi.
  def query_name(latin)
    cleaned = Powo::Matcher.basic_clean(Powo::Matcher.fix_cyrillic_homoglyphs(latin))
    name, = Powo::Matcher.split_scientific_name(cleaned)
    name
  end

  # Nomdagi OXIRGI epitet, kanonik shaklda (jins/imlo farqisiz).
  def last_epithet_key(name)
    ep = name.to_s.split(/\s+/).reject { |t| t.match?(/\A(subsp|ssp|var|f|forma)\.?\z/i) || t.match?(/\A[x×]\z/i) }.last
    ep && Powo::Matcher.canonicalize_word(ep.downcase.delete('-'))
  end

  # Qidiruv natijasidan eng mos yozuvni tanlaydi:
  #   1) nomi AYNAN teng
  #   2) EPITETI mos (kanonik) — POWO fuzzy qidiruvi "setifolium" so'roviga
  #      "Cuminum cyminum" ni birinchi qaytarishi mumkin, shuni oldini oladi
  #   3) hech biri bo'lmasa — birinchi natija, LEKIN "epitet mos emas" bayrog'i bilan
  # Qaytadi: [entry, epithet_ok?]
  def best_result(results, wanted_name)
    return [ nil, false ] if results.blank?

    want = wanted_name.downcase
    if (exact = results.find { |r| r['name'].to_s.downcase == want })
      return [ exact, true ]
    end

    want_ep = last_epithet_key(wanted_name)
    if want_ep && (ep_match = results.find { |r| last_epithet_key(r['name']) == want_ep })
      return [ ep_match, true ]
    end

    [ results.first, false ]
  end

  def fq_id(entry)
    entry['fqId'].presence || entry['url'].to_s[%r{/taxon/(.+)\z}, 1]
  end

  # Bitta nomni POWO'da yechadi -> { accepted_name:, powo_id:, holat: }
  def resolve(latin, delay:)
    qname = query_name(latin)
    status, data = http_get_json("#{SEARCH_URL}?#{URI.encode_www_form(q: qname, perPage: 5)}")
    return { holat: "POWO API xato: #{data}", error: true } if status == :error

    entry, epithet_ok = best_result(data['results'], qname)
    return { holat: "POWO'da topilmadi" } if entry.nil?

    flag = epithet_ok ? '' : ' (epitet mos emas — tekshiring)'

    if entry['accepted'] == true
      return { accepted_name: entry['name'], powo_id: fq_id(entry), holat: "POWO: qabul qilingan nom#{flag}" }
    end

    # Sinonim — accepted yozuvni taxon endpoint orqali olamiz.
    sleep delay
    tstatus, tdata = http_get_json("#{TAXON_URL}/#{fq_id(entry)}")
    if tstatus == :ok && tdata['accepted'].is_a?(Hash)
      acc = tdata['accepted']
      { accepted_name: acc['name'], powo_id: acc['fqId'].presence || fq_id(acc), holat: "POWO: sinonim#{flag}" }
    elsif tstatus == :ok && (so = tdata['synonymOf'] || entry['synonymOf'])
      { accepted_name: so['name'], powo_id: so['fqId'].presence || fq_id(so), holat: "POWO: sinonim#{flag}" }
    else
      { accepted_name: entry['name'], powo_id: fq_id(entry), holat: "POWO: aniqlanmadi (accepted yo'q)#{flag}" }
    end
  end
end

namespace :plants do
  desc "TOPILMADI qolgan nomlarni POWO jonli API orqali tekshirish (db/qoraqalpoq_bazada_yoq.csv)"
  task qoraqalpoq_powo_api: :environment do
    q = QoraqalpoqPowoApi
    delay = (ENV['DELAY'].presence || 1.5).to_f

    # Nomlar ro'yxati: mavjud bazada_yoq.csv dan (qayta yugurtirilsa) yoki
    # import audit hisobotidagi TOPILMADI qatorlaridan.
    names =
      if File.exist?(q::BAZADA_YOQ_PATH)
        CSV.read(q::BAZADA_YOQ_PATH, headers: true).map { |r| r['eski_nom'].to_s.strip }.reject(&:blank?)
      elsif File.exist?(QoraqalpoqImport::REPORT_PATH)
        CSV.read(QoraqalpoqImport::REPORT_PATH, headers: true)
           .select { |r| r['holat'] == QoraqalpoqImport::TOPILMADI }
           .map { |r| r['fayldagi_nom'].to_s.strip }
      else
        abort "XATO: avval `rails plants:import_qoraqalpoq` ni yugurtiring " \
              "(#{QoraqalpoqImport::REPORT_PATH.basename} audit fayli kerak) yoki " \
              "#{q::BAZADA_YOQ_PATH.basename} ni qo'lda tuzing."
      end
    names = names.uniq
    puts "Tekshiriladi: #{names.size} ta nom. So'rovlar orasida #{delay}s kutish."
    puts '=' * 64

    # Bazadagi nomlarni kanonik kalit bo'yicha indekslash (yechilgan nom
    # bazada bormi — tekshirish uchun).
    db_keys = {}
    Plant.select(:id, :species_sci, :accepted_name).find_each do |p|
      [ p.species_sci, p.accepted_name ].compact.each do |n|
        k = Powo::Matcher.canonical_key(n)
        db_keys[k] = n if k.to_s.split(' ').size >= 2
      end
    end

    rows = []
    in_db = []
    consecutive_errors = 0
    names.each_with_index do |latin, i|
      print "  [#{i + 1}/#{names.size}] #{latin} ... "
      out = q.resolve(latin, delay: delay)

      if out[:error]
        consecutive_errors += 1
        rows << [ latin, nil, nil, out[:holat] ]
        puts out[:holat]
        if consecutive_errors >= 5
          puts "\nTO'XTATILDI: ketma-ket 5 ta so'rov xato berdi — POWO API bu muhitdan " \
               "ishonchli ochilmayapti (Cloudflare). Boshqa muhitdan qayta yugurtiring."
          break
        end
        sleep delay unless i == names.size - 1
        next
      end
      consecutive_errors = 0

      acc = out[:accepted_name]
      rows << [ latin, acc, out[:powo_id], out[:holat] ]
      puts "#{out[:holat]}#{acc ? " -> #{acc}" : ''}"

      # hal_qilingan.csv ga FAQAT ishonchli (epitet mos) natijalar qo'shiladi —
      # "epitet mos emas" bayrog'i borlari qo'lda ko'rib chiqiladi.
      if acc && !out[:holat].to_s.include?('mos emas') &&
         (k = Powo::Matcher.canonical_key(acc)) && db_keys.key?(k)
        in_db << [ latin, acc, db_keys[k] ]
      end

      sleep delay unless i == names.size - 1
    end

    # Tekshirilmagan (fatal'dan keyin qolgan) nomlar.
    checked = rows.map(&:first).to_set
    names.reject { |n| checked.include?(n) }.each do |n|
      rows << [ n, nil, nil, 'tekshirilmadi (API to\'xtadi)' ]
    end

    CSV.open(q::BAZADA_YOQ_PATH, 'w', encoding: 'UTF-8') do |csv|
      csv << q::BAZADA_YOQ_HEADERS
      rows.each { |r| csv << r }
    end

    puts "\n#{'=' * 64}"
    puts "#{q::BAZADA_YOQ_PATH} yozildi: #{rows.size} qator."
    resolved = rows.count { |r| r[1].present? }
    puts "  POWO yechgani: #{resolved} ta"
    puts "  shundan bazada BOR: #{in_db.size} ta"
    puts "  bazada YO'Q (haqiqiy bo'shliq): #{resolved - in_db.size} ta"
    puts "  POWO'da ham topilmadi: #{rows.count { |r| r[3].to_s.start_with?('POWO\'da topilmadi') }} ta"

    if in_db.any?
      puts "\nBazada bor — db/qoraqalpoq_nomlari_hal_qilingan.csv ga qo'shilmoqda:"
      in_db.each { |eski, acc, db_name| puts "  #{eski}  ->  #{acc}  (bazada: #{db_name})" }

      resolved_rows = File.exist?(QoraqalpoqImport::RESOLVED_CSV_PATH) ?
        CSV.read(QoraqalpoqImport::RESOLVED_CSV_PATH, headers: true).map(&:to_h) : []
      by_name = resolved_rows.index_by { |r| r['lotincha_nom'] }
      in_db.each do |eski, acc, _|
        if (r = by_name[eski])
          r['hal_qilingan_nom'] = acc
          r['qaysi_bosqich'] = '4-bosqich (POWO API)'
        end
      end
      CSV.open(QoraqalpoqImport::RESOLVED_CSV_PATH, 'w', encoding: 'UTF-8') do |csv|
        csv << QoraqalpoqImport::RESOLVED_HEADERS
        resolved_rows.each { |r| csv << QoraqalpoqImport::RESOLVED_HEADERS.map { |h| r[h] } }
      end
      puts "\nEndi `rails plants:import_qoraqalpoq APPLY=true` ni qayta yugurting."
    end
  end
end
