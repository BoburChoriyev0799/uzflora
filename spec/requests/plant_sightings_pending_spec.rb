require 'spec_helper'

describe 'Plant sightings moderation queue (/plant_sightings/pending)', type: :request do
  let(:regular_user) { FactoryBot.create(:user) }
  let(:expert) { FactoryBot.create(:user, :expert) }
  let(:plant) { Plant.create!(species_sci: 'Testia delta L.') }
  let(:owner) { FactoryBot.create(:user) }
  let!(:pending_sighting) do
    PlantSighting.create!(user: owner, published: true, status: 'pending', timestamp: Time.zone.now,
                           latitude: 41.3, longitude: 69.2, plant_id: plant.id)
  end

  describe 'GET /plant_sightings/pending (access)' do
    it 'redirects a guest to sign in' do
      get pending_plant_sightings_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'is open to any signed-in user, not just experts' do
      sign_in regular_user
      get pending_plant_sightings_path
      expect(response).to have_http_status(:ok)
    end

    it 'is still open to experts' do
      sign_in expert
      get pending_plant_sightings_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /plant_sightings/pending (page content by role)' do
    it 'shows the propose-a-species widget and the crowd-note banner to a regular user, but no approve/reject buttons' do
      sign_in regular_user
      get pending_plant_sightings_path

      # Haml avto-escape sabab apostroflar HTML'da `&#39;` bo'lib chiqadi
      # — solishtirishdan oldin dekod qilinadi.
      expect(CGI.unescapeHTML(response.body)).to include(I18n.t('plant_sightings.pending.crowd_note'))
      expect(response.body).to include('identification-propose-form')
      expect(response.body).not_to include('moderation-approve')
      expect(response.body).not_to include('moderation-reject')
    end

    it 'still shows approve/reject buttons to an expert' do
      sign_in expert
      get pending_plant_sightings_path

      expect(response.body).to include('moderation-approve')
      expect(response.body).to include('moderation-reject')
    end
  end

  describe 'a regular user can propose a species from the queue (crowd identification)' do
    it 'saves the proposal via IdentificationsController#create' do
      sign_in regular_user
      other_plant = Plant.create!(species_sci: 'Testia gamma L.')

      expect {
        post plant_sighting_identifications_path(pending_sighting), params: { plant_id: other_plant.id }, as: :json
      }.to change { pending_sighting.identifications.count }.by(1)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['success']).to be true
    end
  end

  describe 'server-side authorization on the moderation actions themselves' do
    it "does not approve when a regular user posts directly to the approve endpoint" do
      sign_in regular_user
      expect {
        post approve_plant_sighting_path(pending_sighting)
      }.not_to change { pending_sighting.reload.status }
      expect(response).to redirect_to(root_path)
    end

    it "does not reject when a regular user posts directly to the reject endpoint" do
      sign_in regular_user
      expect {
        post reject_plant_sighting_path(pending_sighting)
      }.not_to change { pending_sighting.reload.status }
      expect(response).to redirect_to(root_path)
    end

    it "does not assign a plant when a regular user posts directly to the assign_plant endpoint" do
      other_plant = Plant.create!(species_sci: 'Testia gamma L.')
      sign_in regular_user
      expect {
        post assign_plant_plant_sighting_path(pending_sighting), params: { plant_id: other_plant.id }
      }.not_to change { pending_sighting.reload.plant_id }
      expect(response).to redirect_to(root_path)
    end

    it 'still lets an expert approve directly' do
      sign_in expert
      post approve_plant_sighting_path(pending_sighting)
      expect(pending_sighting.reload.status).to eq('approved')
    end

    it 'still lets an expert reject directly' do
      sign_in expert
      post reject_plant_sighting_path(pending_sighting)
      expect(pending_sighting.reload.status).to eq('rejected')
    end
  end
end
