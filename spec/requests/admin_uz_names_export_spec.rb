require 'spec_helper'
require 'csv'

# 3-ish (davomi): ActiveAdmin'дан "O'zbekcha nomlar CSV" — Render'дан
# brauzer orqali yuklab olish uchun.
describe 'Admin — O`zbekcha nomlar CSV eksporti', type: :request do
  let(:admin) { FactoryBot.create(:user, is_admin: true) }
  before { sign_in admin }

  let!(:with_name)  { Plant.create!(species_sci: 'Named plantus L.', species_uz: 'nomli', primary_record: true) }
  let!(:rare)       { Plant.create!(species_sci: 'Aaa rareus L.', family_lat: 'Zygophyllaceae', primary_record: true) }
  let!(:common)     { Plant.create!(species_sci: 'Zzz communis L.', family_lat: 'Asteraceae', primary_record: true) }
  let!(:red)        { Plant.create!(species_sci: 'Mmm rubrum L.', family_lat: 'Liliaceae', red_book: true, primary_record: true) }

  before do
    PlantSighting.new(user: FactoryBot.create(:user), plant: common, status: 'approved', published: true,
                      timestamp: Time.zone.now, latitude: 41, longitude: 69, photo_status: 'ready').save!(validate: false)
  end

  it 'CSV qaytaradi: faqat species_uz bo`sh turlar, to`g`ri ustunlar va tartib' do
    get '/admin/plants/export_uz_names'

    expect(response).to have_http_status(:ok)
    expect(response.content_type).to include('text/csv')
    expect(response.headers['Content-Disposition']).to include('attachment')

    rows = CSV.parse(response.body, headers: true)
    expect(rows.headers).to eq(UzNamesExport::HEADERS)

    ids = rows['id'].map(&:to_i)
    expect(ids).not_to include(with_name.id)          # species_uz bor -> yo'q
    expect(ids.first).to eq(common.id)                # kuzatuvi bor -> tepada
    expect(ids[1]).to eq(red.id)                      # keyin Qizil kitob
    expect(ids).to include(rare.id)
  end

  it 'oddiy foydalanuvchini kiritmaydi' do
    sign_in FactoryBot.create(:user)
    get '/admin/plants/export_uz_names'
    expect(response).not_to have_http_status(:ok)
  end
end
