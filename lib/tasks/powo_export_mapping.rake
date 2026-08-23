# frozen_string_literal: true
#
# `Powo::Matcher` (lib/powo/matcher.rb) yordamida WCVP bilan solishtiruv
# natijasini `db/powo_mapping.csv` fayliga yozadi. FAQAT O'QIYDI — bazaga
# hech narsa yozmaydi.
#
# NEGA FAYLGA CHIQARAMIZ: `db/external/wcvp_names.csv` (WCVP manba fayli,
# ~287MB) .gitignore'da — u Render serverida YO'Q. Shuning uchun
# `plants:powo_apply` prod serverida to'g'ridan-to'g'ri WCVP'ni o'qiy
# olmaydi. Yechim: bu task WCVP bilan solishtirishni FAQAT lokalda (yoki
# WCVP fayli bor har qanday muhitda) bir marta bajaradi, natijani kichik
# CSV'ga yozadi, shu CSV COMMIT QILINADI va `plants:powo_apply` endi
# FAQAT shu CSV'ni o'qiydi — WCVP yoki Powo::Matcher'ga umuman muhtoj
# emas.
#
# Ishga tushirish:
#   rails plants:powo_export_mapping
require 'csv'
require Rails.root.join('lib', 'powo', 'matcher')

MAPPING_HEADERS = %w[
  species_sci wcvp_matched_name wcvp_status accepted_name accepted_authors
  accepted_family accepted_genus accepted_rank powo_id powo_match_type
].freeze

namespace :plants do
  desc "Powo::Matcher natijasini db/powo_mapping.csv ga yozish (commit qilinadigan, kichik fayl)"
  task powo_export_mapping: :environment do
    begin
      results = Powo::Matcher.run(log: ->(msg) { puts msg })
    rescue RuntimeError => e
      puts "XATO: #{e.message}"
      next
    end

    puts "\nMapping fayli tuzilmoqda..."
    rows = results.map { |r|
      matched = r[:chosen_row]
      final = r[:final]
      {
        'species_sci' => r[:species_sci],
        'wcvp_matched_name' => matched ? "#{matched[:taxon_name]} #{matched[:taxon_authors]}".strip : nil,
        'wcvp_status' => matched&.fetch(:status, nil),
        'accepted_name' => final&.fetch(:taxon_name, nil),
        'accepted_authors' => final&.fetch(:taxon_authors, nil),
        'accepted_family' => final&.fetch(:family, nil),
        'accepted_genus' => final&.fetch(:genus, nil),
        'accepted_rank' => final&.fetch(:rank, nil),
        'powo_id' => final&.fetch(:powo_id, nil),
        'powo_match_type' => r[:match_type].to_s
      }
    }

    # Alifbo tartibi: fayl qayta yaratilganda git diff toza/qisqa bo'lishi
    # uchun (aks holda Plant.order(:id) tartibida ham chiqishi mumkin edi,
    # lekin id o'zi ma'nosiz ma'lumot — species_sci esa barqaror kalit).
    rows.sort_by! { |row| row['species_sci'].to_s }

    path = Rails.root.join('db', 'powo_mapping.csv')
    CSV.open(path, 'w', encoding: 'UTF-8') do |csv|
      csv << MAPPING_HEADERS
      rows.each { |row| csv << MAPPING_HEADERS.map { |h| row[h] } }
    end

    size_kb = (File.size(path) / 1024.0).round(1)
    puts "\n#{'=' * 60}"
    puts "db/powo_mapping.csv yozildi: #{rows.size} qator, #{size_kb} KB"
    puts "  match_type bo'yicha:"
    rows.group_by { |row| row['powo_match_type'] }.sort_by { |_k, v| -v.size }.each do |type, group|
      puts "    #{type}: #{group.size}"
    end
  end
end
