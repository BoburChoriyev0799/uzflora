require 'spec_helper'

# XAVFSIZLIK — Qizil kitob koordinatalarini yashirish. To'rt holat.
describe SightingCoordinates do
  let(:owner)   { FactoryBot.create(:user) }
  let(:expert)  { FactoryBot.create(:user, :expert) }
  let(:guest)   { FactoryBot.create(:user) }

  let(:ordinary_plant)  { Plant.create!(species_sci: 'Ordinaria testensis L.', primary_record: true, red_book: false) }
  let(:red_book_plant)  { Plant.create!(species_sci: 'Tulipa greigii Regel', primary_record: true, red_book: true) }

  # Aniq (yaxlitlanmagan) koordinatalar.
  let(:lat) { 41.31171 }
  let(:lon) { 69.27937 }

  def sighting_for(plant)
    s = PlantSighting.new(user: owner, plant: plant, status: 'approved', published: true,
                          timestamp: Time.zone.now, latitude: lat, longitude: lon)
    s.save!(validate: false)
    s
  end

  context 'tur Qizil kitobda EMAS' do
    it 'har kimga aniq koordinata beradi' do
      result = SightingCoordinates.for(sighting_for(ordinary_plant), guest)
      expect(result[:obscured]).to be(false)
      expect(result[:lat]).to eq(lat)
      expect(result[:lon]).to eq(lon)
    end
  end

  context 'tur Qizil kitobda' do
    it 'egasiga aniq koordinata beradi' do
      result = SightingCoordinates.for(sighting_for(red_book_plant), owner)
      expect(result[:obscured]).to be(false)
      expect(result[:lat]).to eq(lat)
    end

    it 'ekspertga aniq koordinata beradi' do
      result = SightingCoordinates.for(sighting_for(red_book_plant), expert)
      expect(result[:obscured]).to be(false)
      expect(result[:lat]).to eq(lat)
    end

    it 'qolgan hamma uchun 0.1 gradusga yaxlitlaydi' do
      result = SightingCoordinates.for(sighting_for(red_book_plant), guest)
      expect(result[:obscured]).to be(true)
      expect(result[:lat]).to eq(41.3)
      expect(result[:lon]).to eq(69.3)
      # Aniq qiymat umuman qaytmaydi.
      expect(result[:lat]).not_to eq(lat)
    end

    it 'mehmon (viewer nil) uchun ham yaxlitlaydi' do
      result = SightingCoordinates.for(sighting_for(red_book_plant), nil)
      expect(result[:obscured]).to be(true)
      expect(result[:lat]).to eq(41.3)
    end

    it "group_red_book (sinonim nom) bo'yicha ham himoyalaydi" do
      grouped = Plant.create!(species_sci: 'Synonyma redbookia L.', primary_record: true,
                              red_book: false, group_red_book: true)
      result = SightingCoordinates.for(sighting_for(grouped), guest)
      expect(result[:obscured]).to be(true)
    end
  end

  it "koordinata yo'q bo'lsa nil qaytaradi" do
    s = PlantSighting.new(user: owner, plant: ordinary_plant, status: 'approved', published: true)
    s.save!(validate: false)
    expect(SightingCoordinates.for(s, owner)).to be_nil
  end
end
