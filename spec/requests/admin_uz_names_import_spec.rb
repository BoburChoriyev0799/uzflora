require 'spec_helper'

# O'zbekcha nomlarni yuklash sahifasi (ActiveAdmin) — KO'RIB CHIQISH +
# TASDIQLASH oqimi, admin-only.
describe 'Admin — O`zbekcha nomlarni yuklash', type: :request do
  let(:admin)   { FactoryBot.create(:user, is_admin: true) }
  let(:expert)  { FactoryBot.create(:user, is_expert: true) }
  let(:regular) { FactoryBot.create(:user) }

  let!(:plant) { Plant.create!(species_sci: 'Tulipa uploada Regel', accepted_name: 'Tulipa uploada', primary_record: true) }

  def csv_file(body, name: 'nomlar.csv', type: 'text/csv')
    Rack::Test::UploadedFile.new(StringIO.new(body), type, original_filename: name)
  end

  let(:good_csv) do
    "id,lotincha_nom,qabul_qilingan_nom,oila,ruscha_nom,qoraqalpoqcha_nom,qizil_kitob,kuzatuvlar_soni,species_uz\n" \
    "#{plant.id},Tulipa uploada,,,,,,,yuklangan lola\n"
  end

  # --- XAVFSIZLIK ---
  describe 'ruxsat (faqat admin)' do
    it 'oddiy foydalanuvchi sahifaga kira olmaydi' do
      sign_in regular
      get admin_ozbekcha_nomlar_import_path
      expect(response).not_to have_http_status(:ok)
      expect(response).to have_http_status(:redirect)
    end

    it 'ekspert ham kira olmaydi' do
      sign_in expert
      get admin_ozbekcha_nomlar_import_path
      expect(response).not_to have_http_status(:ok)
    end

    it 'oddiy foydalanuvchi apply endpointiga urinsa — HECH NARSA yozilmaydi' do
      sign_in regular
      post admin_ozbekcha_nomlar_import_apply_path, params: { csv_b64: Base64.strict_encode64(good_csv) }
      expect(response).not_to have_http_status(:ok)
      expect(plant.reload.species_uz).to be_nil
    end

    it 'oddiy foydalanuvchi preview endpointiga urinsa — HECH NARSA yozilmaydi' do
      sign_in regular
      post admin_ozbekcha_nomlar_import_preview_path, params: { file: csv_file(good_csv) }
      expect(response).not_to have_http_status(:ok)
      expect(plant.reload.species_uz).to be_nil
    end

    it 'admin -> 200' do
      sign_in admin
      get admin_ozbekcha_nomlar_import_path
      expect(response).to have_http_status(:ok)
    end
  end

  # --- KO'RIB CHIQISH hech narsa yozmaydi ---
  describe 'preview' do
    before { sign_in admin }

    it 'planни ko`rsatadi, LEKIN bazaga hech narsa yozmaydi' do
      post admin_ozbekcha_nomlar_import_preview_path, params: { file: csv_file(good_csv) }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Qo')  # "Qo'shiladi"
      expect(response.body).to include('yuklangan lola')
      expect(plant.reload.species_uz).to be_nil # YOZILMADI
    end

    it 'CSV bo`lmagan fayl -> tushunarli xato (500 emas)' do
      post admin_ozbekcha_nomlar_import_preview_path,
           params: { file: csv_file('binary', name: 'rasm.png', type: 'image/png') }
      expect(response).to redirect_to(admin_ozbekcha_nomlar_import_path)
      follow_redirect!
      expect(response.body).to include('CSV')
    end

    it 'ustunlari mos kelmagan CSV -> tushunarli xato' do
      post admin_ozbekcha_nomlar_import_preview_path,
           params: { file: csv_file("lotincha,nom\nA,b") }
      follow_redirect!
      expect(response.body).to include('ustun')
    end
  end

  # --- TASDIQLASH yozadi ---
  describe 'apply' do
    before { sign_in admin }

    it 'tasdiqlangач guruhning barcha a`zolariga yozadi' do
      member = Plant.create!(species_sci: 'Tulipa uploada-syn Bunge', accepted_name: 'Tulipa uploada',
                             wcvp_status: 'Synonym', primary_record: false)
      post admin_ozbekcha_nomlar_import_apply_path, params: { csv_b64: Base64.strict_encode64(good_csv) }
      expect(response).to redirect_to(admin_ozbekcha_nomlar_import_path)
      expect(plant.reload.species_uz).to eq('yuklangan lola')
      expect(member.reload.species_uz).to eq('yuklangan lola')
    end

    it 'mavjud qiymat ustiga YOZMAYDI (ZIDDIYAT)' do
      plant.update_column(:species_uz, 'eski nom')
      post admin_ozbekcha_nomlar_import_apply_path, params: { csv_b64: Base64.strict_encode64(good_csv) }
      expect(plant.reload.species_uz).to eq('eski nom')
    end
  end
end
