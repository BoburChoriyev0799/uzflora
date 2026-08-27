require 'spec_helper'

# 2026-08-27: /plants va o'simlik sahifasi rasmi bo'sh (fayl yuklanmagan
# yoki hali tayyor bo'lmagan) tasdiqlangan kuzatuv borligida 500 bilan
# yiqilardi (`sighting.photo.small.url` blank uploaderga chaqirilganda).
# Guruh a'zolaridan rasm olish (`@sightings_by_plant`) bu ehtimolni
# oshirdi. Maqsad: bu holat qaytib kelmasin.
describe 'Plants pages with a photo-less approved sighting', type: :request do
  let(:user) { FactoryBot.create(:user) }

  before { sign_in user }

  def broken_sighting_for(plant)
    sighting = PlantSighting.new(user: user, plant: plant, status: 'approved', published: true, timestamp: Time.zone.now)
    sighting.save!(validate: false)
    sighting
  end

  context 'a standalone plant (no accepted_name group)' do
    let!(:plant) { Plant.create!(species_sci: 'Standalonia testensis L.', primary_record: true) }
    let!(:sighting) { broken_sighting_for(plant) }

    it 'renders the plants list without error' do
      get plants_path
      expect(response).to have_http_status(:ok)
    end

    it "renders the plant's own show page without error" do
      get plant_path(plant)
      expect(response).to have_http_status(:ok)
    end
  end

  context "a photo-less sighting on a HIDDEN (non-primary) group member" do
    let!(:primary_plant) do
      Plant.create!(species_sci: 'Groupia primaria L.', accepted_name: 'Groupia primaria', wcvp_status: 'Accepted', primary_record: true)
    end
    let!(:hidden_member) do
      Plant.create!(species_sci: 'Groupia synonyma L.', accepted_name: 'Groupia primaria', wcvp_status: 'Synonym', primary_record: false)
    end
    let!(:sighting) { broken_sighting_for(hidden_member) }

    it "renders the plants list without error (card borrows the group's sightings)" do
      get plants_path
      expect(response).to have_http_status(:ok)
    end

    it "renders the primary's show page without error (aggregates the hidden member's sightings)" do
      get plant_path(primary_plant)
      expect(response).to have_http_status(:ok)
    end
  end

  context 'the guest welcome page' do
    let!(:plant) { Plant.create!(species_sci: 'Welcomia testensis L.', primary_record: true) }
    let!(:sighting) { broken_sighting_for(plant) }

    it 'renders without signing in, without error' do
      sign_out user
      get root_path
      expect(response).to have_http_status(:ok)
    end
  end
end
