# frozen_string_literal: true
#
# devise-two-factor gemi talab qiladigan ustunlar. otp_secret AR encryption
# orqali (config/credentials.yml.enc'даgi active_record_encryption kaliti
# bilan) avtomatik shifrlangan holda saqlanadi — plain matn sifatida
# bazaga yozilmaydi. otp_backup_codes har biri alohida hash qilingan
# (Devise::Encryptor) bir martalik zaxira kodlar massivi.
#
class AddTwoFactorToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :otp_secret, :string
    add_column :users, :consumed_timestep, :integer
    add_column :users, :otp_required_for_login, :boolean, default: false, null: false
    add_column :users, :otp_backup_codes, :string, array: true, default: []
  end
end
