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
    it 'saves the proposal via IdentificationsController#create and returns fresh widget html with the updated count' do
      sign_in regular_user
      other_plant = Plant.create!(species_sci: 'Testia gamma L.')

      expect {
        post plant_sighting_identifications_path(pending_sighting), params: { plant_id: other_plant.id }, as: :json
      }.to change { pending_sighting.identifications.count }.by(1)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['success']).to be true
      # Yangi HTML — kelishuv chizig'ining 1/3 to'lganini ko'rsatadi
      # (progress-segment.filled bitta bo'lishi kerak).
      expect(body['html'].scan('identification-progress-segment filled').size).to eq(1)
      expect(body['html']).to include(regular_user.full_name)
    end

    it 'shows a clear error when no plant was selected' do
      sign_in regular_user
      expect {
        post plant_sighting_identifications_path(pending_sighting), params: {}, as: :json
      }.not_to change { pending_sighting.identifications.count }

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body['success']).to be false
      expect(body['error']).to eq(I18n.t('plant_not_found', scope: 'identifications'))
    end

    it 'updates the same identification instead of creating a duplicate when a user proposes twice' do
      sign_in regular_user
      plant_a = Plant.create!(species_sci: 'Testia alpha L.')
      plant_b = Plant.create!(species_sci: 'Testia beta L.')

      post plant_sighting_identifications_path(pending_sighting), params: { plant_id: plant_a.id }, as: :json
      expect {
        post plant_sighting_identifications_path(pending_sighting), params: { plant_id: plant_b.id }, as: :json
      }.not_to change { pending_sighting.identifications.count }

      expect(pending_sighting.identifications.sole.plant_id).to eq(plant_b.id)
    end

    it 'auto-approves and marks research_grade once three different users agree on the same species' do
      other_plant = Plant.create!(species_sci: 'Testia gamma L.')
      [regular_user, FactoryBot.create(:user), FactoryBot.create(:user)].each do |user|
        sign_in user
        post plant_sighting_identifications_path(pending_sighting), params: { plant_id: other_plant.id }, as: :json
        sign_out user
      end

      pending_sighting.reload
      expect(pending_sighting.status).to eq('approved')
      expect(pending_sighting.research_grade).to be true
      expect(pending_sighting.plant_id).to eq(other_plant.id)
    end
  end

  describe 'a guest cannot propose' do
    it 'shows a sign-in prompt instead of the propose widget on the sighting show page' do
      get plant_sighting_path(pending_sighting)
      expect(response.body).to include('identification-guest-note')
      expect(response.body).not_to include('identification-propose-form')
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
