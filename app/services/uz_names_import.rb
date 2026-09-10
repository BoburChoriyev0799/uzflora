# frozen_string_literal: true
#
# O'zbekcha nom (`species_uz`) importi — BITTA manba: `plants:import_uz_names`
# rake task VA ActiveAdmin "O'zbekcha nomlarni yuklash" sahifasi shu yerni
# chaqiradi (ikki joyda ikki mantiq bo'lmasin).
#
# QOIDALAR:
#   - moslashtirish FAQAT `id` bo'yicha (nom bo'yicha emas — xavfsiz)
#   - `species_uz` bo'sh qatorlar jim o'tkaziladi (xato emas)
#   - mavjud `species_uz` bo'sh BO'LMASA va yangi qiymat farq qilsa —
#     USTIGA YOZILMAYDI ("ZIDDIYAT")
#   - guruhga qo'llash: accepted_name guruhining BARCHA a'zolariga
#   - idempotent
#
# `plan(csv_text)` -> Plan: nima bo'lishini KO'RSATADI, bazaga TEGMAYDI.
# `apply!(plan)` -> Plan'даgi yozuvlarni bitta transaction'да yozadi.
require 'csv'

module UzNamesImport
  class InvalidFile < StandardError; end

  REQUIRED_HEADERS = %w[id species_uz].freeze
  SAMPLE_LIMIT = 20

  Plan = Struct.new(
    :added, :already, :skipped_blank, :conflicts, :not_found_ids,
    :to_write, :sample, keyword_init: true
  ) do
    def write_count = to_write.size
    def any_changes? = to_write.any?
  end

  Row = Struct.new(:id, :name, :status, :note, keyword_init: true)

  module_function

  def plan(csv_text)
    table = parse(csv_text)

    plants = Plant.select(:id, :species_sci, :accepted_name, :species_uz).to_a
    by_id = plants.index_by(&:id)
    by_accepted = plants.select { |p| p.accepted_name.present? }
                        .group_by(&:accepted_name).transform_values { |ps| ps.map(&:id) }

    p = Plan.new(added: 0, already: 0, skipped_blank: 0, conflicts: [], not_found_ids: [],
                 to_write: {}, sample: [])

    table.each do |csv_row|
      name = csv_row['species_uz'].to_s.strip
      if name.blank?
        p.skipped_blank += 1
        next
      end

      raw_id = csv_row['id'].to_s.strip
      anchor = by_id[raw_id.to_i]
      if anchor.nil?
        p.not_found_ids << raw_id
        add_sample(p, raw_id, name, 'TOPILMADI', "id bazada yo'q")
        next
      end

      group_ids = anchor.accepted_name.present? ? (by_accepted[anchor.accepted_name] || [ anchor.id ]) : [ anchor.id ]
      group = group_ids.filter_map { |gid| by_id[gid] }
      existing = group.filter_map { |pl| pl.species_uz.presence }.uniq

      if existing.any? && existing != [ name ]
        p.conflicts << { id: anchor.id, species_sci: anchor.species_sci, existing: existing.join(' / '), csv: name }
        add_sample(p, anchor.id, name, 'ZIDDIYAT', "bazada: #{existing.join(' / ')}")
        next
      end

      pending = group.reject { |pl| pl.species_uz == name }
      if pending.empty?
        p.already += 1
        add_sample(p, anchor.id, name, 'ALLAQACHON_BOR', nil)
        next
      end

      pending.each { |pl| p.to_write[pl.id] = name }
      p.added += 1
      note = group.size > 1 ? "guruh: #{pending.size}/#{group.size} a'zoga" : nil
      add_sample(p, anchor.id, name, "QO'SHILADI", note)
    end

    p
  end

  def apply!(plan)
    return 0 if plan.to_write.empty?

    now = Time.zone.now
    Plant.transaction do
      plan.to_write.group_by { |_, name| name }.each do |name, pairs|
        Plant.where(id: pairs.map(&:first)).update_all(species_uz: name, updated_at: now)
      end
    end
    plan.to_write.size
  end

  # --- ichki ---

  def parse(csv_text)
    clean = csv_text.to_s.dup.force_encoding('UTF-8').delete_prefix("﻿") # Excel BOM
    table = CSV.parse(clean, headers: true)
    missing = REQUIRED_HEADERS - table.headers.map { |h| h.to_s.strip }
    raise InvalidFile, "kerakli ustun(lar) yo'q: #{missing.join(', ')}" if missing.any?

    table
  rescue CSV::MalformedCSVError => e
    raise InvalidFile, "CSV o'qib bo'lmadi (#{e.message})"
  end

  def add_sample(plan, id, name, status, note)
    return if plan.sample.size >= SAMPLE_LIMIT

    plan.sample << Row.new(id: id, name: name, status: status, note: note)
  end
end
