require 'spec_helper'

# 1-ish: modelning to'liq tahrirlashga tegishli qismlari — kelajakdagi
# sana validatsiyasi va rasm almashtirilganda aniqlashlarni tiklash.
describe PlantSighting, type: :model do
  describe 'timestamp validation' do
    it 'kelajakdagi sanani rad etadi' do
      s = PlantSighting.new(user: FactoryBot.create(:user), timestamp: 1.day.from_now)
      expect(s).not_to be_valid
      expect(s.errors[:timestamp]).to be_present
    end

    it 'o`tmishdagi/bugungi sanani qabul qiladi' do
      s = PlantSighting.new(user: FactoryBot.create(:user), timestamp: Time.zone.now)
      s.valid?
      expect(s.errors[:timestamp]).to be_empty
    end

    it 'sana bo`sh bo`lsa tekshirmaydi' do
      s = PlantSighting.new(user: FactoryBot.create(:user), timestamp: nil)
      s.valid?
      expect(s.errors[:timestamp]).to be_empty
    end
  end

  describe '#reset_after_photo_replacement!' do
    let(:user) { FactoryBot.create(:user) }
    let(:plant) { Plant.create!(species_sci: 'Resetia testensis L.', primary_record: true) }

    def sighting(attrs = {})
      s = PlantSighting.new({ user: user, plant: plant, timestamp: Time.zone.now, photo_status: 'ready' }.merge(attrs))
      s.save!(validate: false)
      s
    end

    it 'tasdiqlangan/baholangan kuzatuvni pending`ga qaytaradi, hisoblagichlarni nolga tushiradi' do
      s = sighting(status: 'approved', research_grade: true, agreement_count: 3, research_graded_at: 1.day.ago)
      s.reset_after_photo_replacement!
      expect(s.reload.status).to eq('pending')
      expect(s.research_grade).to be(false)
      expect(s.research_graded_at).to be_nil
      expect(s.agreement_count).to eq(0)
    end

    it 'identifications yozuvlarini O`CHIRMAYDI' do
      voter = FactoryBot.create(:user)
      s = sighting(status: 'approved')
      s.propose_identification!(voter, plant)
      expect { s.reset_after_photo_replacement! }.not_to change { s.identifications.count }
    end

    it 'har doim photo_replaced_at ni belgilaydi' do
      s = sighting
      expect { s.reset_after_photo_replacement! }.to change { s.reload.photo_replaced_at }.from(nil)
    end

    it 'yo`qotadigan narsasi bo`lmagan (aniqlashi yo`q, pending, baholanmagan) kuzatuvda status/agreement o`zgarmaydi' do
      s = sighting(status: 'pending', research_grade: false, agreement_count: 0)
      s.reset_after_photo_replacement!
      expect(s.reload.status).to eq('pending')
      expect(s.agreement_count).to eq(0)
    end
  end
end
