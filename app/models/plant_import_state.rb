# frozen_string_literal: true
#
# Bitta qatorli (singleton) jadval — `plants:import` rake task oxirgi
# muvaffaqiyatli import qilgan CSV faylning checksum'ini shu yerda
# saqlaydi, shunda har deploy'da CSV o'zgarmagan bo'lsa import qayta
# ishga tushirilmaydi (4412 qatorni har safar o'qib o'tirish shart emas).
#
class PlantImportState < ApplicationRecord
  def self.singleton
    first_or_initialize
  end
end
