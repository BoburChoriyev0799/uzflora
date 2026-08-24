# frozen_string_literal: true

# `expert_id` KIM TASDIQLADI/RAD ETDI degan ma'noni bildiradi va shu
# ma'noda qoladi. Turni KIM ANIQLAGANI (assign_plant orqali) — butunlay
# alohida ustun: bitta kuzatuvni bir ekspert aniqlab, boshqasi tasdiqlashi
# mumkin, ikkalasi bir xil odam bo'lishi shart emas.
class AddIdentifiedByToPlantSightings < ActiveRecord::Migration[7.1]
  def change
    add_reference :plant_sightings, :identified_by, foreign_key: { to_table: :users }, index: true
  end
end
