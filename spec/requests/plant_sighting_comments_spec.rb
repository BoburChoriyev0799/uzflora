require 'spec_helper'

describe 'Plant sighting comments', type: :request do
  let(:owner) { FactoryBot.create(:user) }
  let(:commenter) { FactoryBot.create(:user) }
  let(:expert) { FactoryBot.create(:user, :expert) }
  let(:plant) { Plant.create!(species_sci: 'Testia delta L.') }
  let(:sighting) do
    PlantSighting.create!(user: owner, published: true, status: 'approved', timestamp: Time.zone.now,
                           latitude: 41.3, longitude: 69.2, plant_id: plant.id)
  end

  describe 'POST /plant_sighting_comments' do
    it 'requires authentication' do
      post plant_sighting_comments_path, params: { comment: 'salom', plant_sighting_id: sighting.id }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates a comment, bumps the counter cache, and notifies the owner' do
      sign_in commenter
      expect {
        post plant_sighting_comments_path, params: { comment: 'Chiroyli gul ekan!', plant_sighting_id: sighting.id }, as: :json
      }.to change { sighting.reload.comments_count }.from(0).to(1)
        .and change(Notification, :count).by(1)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['success']).to be true
      expect(body['html']).to include('Chiroyli gul ekan!')

      notification = Notification.last
      expect(notification.notification_type).to eq('new_comment')
      expect(notification.recipient_id).to eq(owner.id)
    end

    it 'escapes HTML in the rendered comment (XSS protection)' do
      sign_in commenter
      post plant_sighting_comments_path,
           params: { comment: '<script>alert(1)</script>', plant_sighting_id: sighting.id }, as: :json
      body = JSON.parse(response.body)
      expect(body['html']).not_to include('<script>alert(1)</script>')
      expect(body['html']).to include('&lt;script&gt;')
    end

    it 'rejects a comment over 100 characters' do
      sign_in commenter
      post plant_sighting_comments_path, params: { comment: 'a' * 101, plant_sighting_id: sighting.id }, as: :json
      expect(JSON.parse(response.body)['success']).to be false
      expect(sighting.reload.comments_count).to eq(0)
    end

    it "does not notify the owner about their own comment" do
      sign_in owner
      expect {
        post plant_sighting_comments_path, params: { comment: "o'z izohim", plant_sighting_id: sighting.id }, as: :json
      }.not_to change(Notification, :count)
    end
  end

  describe 'DELETE /plant_sighting_comments/:id' do
    let!(:comment) { PlantSightingComment.create!(user: commenter, plant_sighting: sighting, text: 'test') }

    it 'lets the comment owner delete it' do
      sign_in commenter
      delete plant_sighting_comment_path(comment), as: :json
      expect(PlantSightingComment.exists?(comment.id)).to be false
      expect(sighting.reload.comments_count).to eq(0)
    end

    it "lets an expert delete someone else's comment" do
      sign_in expert
      delete plant_sighting_comment_path(comment), as: :json
      expect(PlantSightingComment.exists?(comment.id)).to be false
    end

    it "does not let an unrelated regular user delete someone else's comment" do
      other = FactoryBot.create(:user)
      sign_in other
      delete plant_sighting_comment_path(comment), as: :json
      expect(PlantSightingComment.exists?(comment.id)).to be true
    end
  end
end
