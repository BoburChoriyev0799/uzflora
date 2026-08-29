require 'spec_helper'

describe 'Identifications', type: :request do
  let(:owner) { FactoryBot.create(:user) }
  let(:voter) { FactoryBot.create(:user) }
  let(:expert) { FactoryBot.create(:user, :expert) }
  let(:plant) { Plant.create!(species_sci: 'Testia gamma L.') }
  let(:sighting) do
    PlantSighting.create!(user: owner, published: true, timestamp: Time.zone.now,
                           latitude: 41.3, longitude: 69.2, plant_id: plant.id)
  end

  describe 'POST /plant_sightings/:id/identifications' do
    it 'requires authentication' do
      post plant_sighting_identifications_path(sighting), params: { plant_id: plant.id }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'lets any signed-in user propose an identification' do
      sign_in voter
      post plant_sighting_identifications_path(sighting), params: { plant_id: plant.id }, as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['success']).to be true
      expect(sighting.reload.identifications_count).to eq(1)
    end

    it 'rejects a non-existent plant_id' do
      sign_in voter
      post plant_sighting_identifications_path(sighting), params: { plant_id: -1 }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'DELETE /identifications/:id' do
    let!(:identification) { sighting.propose_identification!(voter, plant) }

    it "lets the owner withdraw their own identification" do
      sign_in voter
      delete identification_path(identification), as: :json
      expect(response).to have_http_status(:ok)
      expect(identification.reload.withdrawn_at).to be_present
    end

    it "lets an expert remove someone else's identification (hard delete)" do
      sign_in expert
      expect {
        delete identification_path(identification), as: :json
      }.to change(Identification, :count).by(-1)
      expect(response).to have_http_status(:ok)
    end

    it "forbids an unrelated regular user from removing someone else's identification" do
      other = FactoryBot.create(:user)
      sign_in other
      delete identification_path(identification), as: :json
      expect(response).to have_http_status(:forbidden)
      expect(identification.reload.withdrawn_at).to be_nil
    end
  end
end
