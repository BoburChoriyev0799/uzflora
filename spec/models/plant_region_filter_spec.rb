require 'spec_helper'

# 2d-ish: /plants viloyat filtri — "shu viloyatда kamida bitta
# TASDIQLANGAN kuzatuvi bo`lgan turlar" (GURUH darajasida).
describe Plant, '.in_region', type: :model do
  let(:user) { FactoryBot.create(:user) }

  let!(:primary) do
    Plant.create!(species_sci: 'Tulipa regionalis Regel', accepted_name: 'Tulipa regionalis',
                  family_lat: 'Liliaceae', primary_record: true)
  end
  let!(:hidden_member) do
    Plant.create!(species_sci: 'Tulipa vetusta Bunge', accepted_name: 'Tulipa regionalis',
                  family_lat: 'Liliaceae', wcvp_status: 'Synonym', primary_record: false)
  end
  let!(:other_plant) do
    Plant.create!(species_sci: 'Rosa aliena L.', accepted_name: 'Rosa aliena',
                  family_lat: 'Rosaceae', primary_record: true)
  end

  def sighting(plant:, region:, status: 'approved', published: true)
    s = PlantSighting.new(user: user, plant: plant, status: status, published: published,
                          timestamp: Time.zone.now, latitude: 41.0, longitude: 69.0, photo_status: 'ready')
    s.region = region
    s.save!(validate: false)
    s
  end

  it 'faqat shu viloyatда approved kuzatuvi bor turlarni qaytaradi' do
    sighting(plant: other_plant, region: 'samarqand')
    sighting(plant: primary, region: 'xorazm')

    result = Plant.where(primary_record: true).merge(Plant.in_region('xorazm'))
    expect(result).to contain_exactly(primary)
  end

  it 'kuzatuv NON-PRIMARY guruh a`zosiga bog`langan bo`lsa ham PRIMARY vakili chiqadi' do
    sighting(plant: hidden_member, region: 'buxoro')

    result = Plant.where(primary_record: true).merge(Plant.in_region('buxoro'))
    expect(result).to contain_exactly(primary)
  end

  it 'faqat pending/rad etilgan yoki nashr qilinmagan kuzatuv -> turni QAYTARMAYDI' do
    sighting(plant: primary, region: 'jizzax', status: 'pending')
    sighting(plant: other_plant, region: 'jizzax', published: false)

    result = Plant.where(primary_record: true).merge(Plant.in_region('jizzax'))
    expect(result).to be_empty
  end

  it 'oila filtri bilan birga ishlaydi' do
    sighting(plant: primary, region: 'navoiy')
    sighting(plant: other_plant, region: 'navoiy')

    result = Plant.where(primary_record: true)
                  .merge(Plant.in_region('navoiy'))
                  .by_family('Rosaceae')
    expect(result).to contain_exactly(other_plant)
  end

  it 'bo`sh kalitda hamma narsani qaytaradi (filtrsiz)' do
    expect(Plant.in_region(nil).count).to eq(Plant.count)
  end

  it 'hech qanday kuzatuvi yo`q viloyatда bo`sh natija' do
    sighting(plant: primary, region: 'andijon')
    expect(Plant.where(primary_record: true).merge(Plant.in_region('fargona'))).to be_empty
  end

  # UNUMDORLIK: filtr korrelyatsiyalangan ichki so'rovsiz — asosiy so'rov
  # SQL'ida `plant_sightings` ga JOIN yoki SELECT bo'lmasin.
  it 'asosiy so`rovда korrelyatsiyalangan ichki so`rov yo`q' do
    sighting(plant: primary, region: 'sirdaryo')
    sql = Plant.where(primary_record: true).merge(Plant.in_region('sirdaryo')).to_sql
    expect(sql).not_to include('plant_sightings')
    expect(sql.scan(/SELECT/i).size).to eq(1)
  end
end
