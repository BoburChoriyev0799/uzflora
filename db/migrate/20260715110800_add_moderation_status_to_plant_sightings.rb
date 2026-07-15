# frozen_string_literal: true
#
# Moderatsiya poydevori: expert_id (allaqachon mavjud) va published (o'z
# holicha qoladi — "ko'rinadimi" degan boshqa savol) yetarli emas edi,
# chunki ular ikkilik (bor/yo'q) edi va "rad etilgan" holatni ifodalay
# olmasdi. Endi aniq uch holat: kutilmoqda / tasdiqlangan / rad etilgan.
#
class AddModerationStatusToPlantSightings < ActiveRecord::Migration[7.1]
  def up
    add_column :plant_sightings, :status, :string, default: 'pending', null: false
    add_column :plant_sightings, :reviewed_at, :datetime
    add_index :plant_sightings, :status

    # Mavjud yozuvlar orasida expert_id allaqachon to'ldirilgan bo'lsa (eski
    # ikkilik "tasdiqlangan" tizimidan qolgan), ularni "approved" deb
    # belgilaymiz — aks holda yangi ustun standart qiymati "pending" qoladi.
    execute "UPDATE plant_sightings SET status = 'approved', reviewed_at = updated_at WHERE expert_id IS NOT NULL"
  end

  def down
    remove_index :plant_sightings, :status
    remove_column :plant_sightings, :reviewed_at
    remove_column :plant_sightings, :status
  end
end
