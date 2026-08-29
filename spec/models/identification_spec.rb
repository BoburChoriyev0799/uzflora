require 'spec_helper'

# Jamoaviy aniqlash (community identification) — qoidalarni tasdiqlaydi:
# 3 ta yakka g'olib -> avtomatik tasdiqlash, teng ovozda tasdiqlanmaslik,
# ekspert taklifi hammasidan ustunligi, va ovoz qaytarib olinganda qayta
# hisoblash. Ko'rish: PlantSighting#recompute_identifications!.
describe 'Community identification', type: :model do
  let(:owner) { FactoryBot.create(:user) }
  let(:voter1) { FactoryBot.create(:user) }
  let(:voter2) { FactoryBot.create(:user) }
  let(:voter3) { FactoryBot.create(:user) }
  let(:expert) { FactoryBot.create(:user, :expert) }
  let(:plant_a) { Plant.create!(species_sci: 'Testia alpha L.') }
  let(:plant_b) { Plant.create!(species_sci: 'Testia beta L.') }

  let(:sighting) do
    PlantSighting.create!(user: owner, published: true, timestamp: Time.zone.now,
                           latitude: 41.3, longitude: 69.2, plant_id: plant_a.id)
  end

  it 'does not auto-approve with only 2 agreeing identifications' do
    sighting.propose_identification!(owner, plant_a)
    sighting.propose_identification!(voter1, plant_a)

    sighting.reload
    expect(sighting.agreement_count).to eq(2)
    expect(sighting.identifications_count).to eq(2)
    expect(sighting.research_grade?).to be false
    expect(sighting).to be_pending
  end

  it 'auto-approves and marks research_grade on the 3rd unique-winner agreement' do
    sighting.propose_identification!(owner, plant_a)
    sighting.propose_identification!(voter1, plant_a)
    sighting.propose_identification!(voter2, plant_a)

    sighting.reload
    expect(sighting.agreement_count).to eq(3)
    expect(sighting.research_grade?).to be true
    expect(sighting).to be_approved
    expect(sighting.plant_id).to eq(plant_a.id)
    expect(sighting.expert_id).to be_nil
  end

  it 'does not auto-approve a 3-3 tie' do
    sighting.propose_identification!(owner, plant_a)
    sighting.propose_identification!(voter1, plant_a)
    sighting.propose_identification!(voter2, plant_a)
    sighting.propose_identification!(voter3, plant_b)
    sighting.propose_identification!(FactoryBot.create(:user), plant_b)
    sighting.propose_identification!(FactoryBot.create(:user), plant_b)

    sighting.reload
    expect(sighting.research_grade?).to be false
    expect(sighting).to be_pending
  end

  it "demotes back to pending when a withdrawal breaks a team-earned research_grade" do
    sighting.propose_identification!(owner, plant_a)
    sighting.propose_identification!(voter1, plant_a)
    v2_identification = sighting.propose_identification!(voter2, plant_a)
    sighting.reload
    expect(sighting.research_grade?).to be true

    sighting.withdraw_identification!(v2_identification)
    sighting.reload
    expect(sighting.research_grade?).to be false
    expect(sighting).to be_pending
  end

  it "an expert's identification wins immediately, even with a single vote" do
    sighting.propose_identification!(voter1, plant_a)
    sighting.propose_identification!(voter2, plant_a)
    sighting.propose_identification!(expert, plant_b)

    sighting.reload
    expect(sighting.research_grade?).to be true
    expect(sighting).to be_approved
    expect(sighting.plant_id).to eq(plant_b.id)
    expect(sighting.expert_id).to eq(expert.id)
  end

  it 'ignores further team votes/withdrawals once an expert has weighed in' do
    sighting.propose_identification!(expert, plant_b)
    sighting.reload
    expect(sighting.research_grade?).to be true

    v1_identification = sighting.propose_identification!(voter1, plant_a)
    sighting.propose_identification!(voter2, plant_a)
    sighting.propose_identification!(voter3, plant_a)
    sighting.withdraw_identification!(v1_identification)

    sighting.reload
    expect(sighting.research_grade?).to be true
    expect(sighting).to be_approved
    expect(sighting.plant_id).to eq(plant_b.id)
    expect(sighting.expert_id).to eq(expert.id)
  end

  it "prevents a second row for the same (sighting, user) pair — changing one's mind updates in place" do
    sighting.propose_identification!(voter1, plant_a)
    sighting.propose_identification!(voter1, plant_b)

    expect(sighting.identifications.count).to eq(1)
    expect(sighting.identifications.active.first.plant_id).to eq(plant_b.id)
  end

  it "notifies the sighting owner when someone else proposes an identification, but not for the owner's own proposal" do
    expect {
      sighting.propose_identification!(owner, plant_a)
    }.not_to change(Notification, :count)

    expect {
      sighting.propose_identification!(voter1, plant_a)
    }.to change(Notification, :count).by(1)

    notification = Notification.last
    expect(notification.recipient_id).to eq(owner.id)
    expect(notification.actor_id).to eq(voter1.id)
    expect(notification.notification_type).to eq('new_identification')
  end
end
