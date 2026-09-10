require 'spec_helper'

# 2-ish: koordinatadan viloyat kalitini aniqlash (sof Ruby ray-casting,
# Natural Earth poligonlari).
describe RegionLookup do
  describe '.region_for' do
    it 'viloyat ICHIDAGI nuqta -> o`sha viloyat kaliti' do
      expect(described_class.region_for(41.311, 69.279)).to eq('toshkent_shahri') # Toshkent
      expect(described_class.region_for(39.654, 66.960)).to eq('samarqand')       # Samarqand
      expect(described_class.region_for(42.460, 59.610)).to eq('qoraqalpogiston') # Nukus
      expect(described_class.region_for(37.224, 67.278)).to eq('surxondaryo')     # Termiz
    end

    it 'O`zbekistondan TASHQARIDAGI nuqta -> nil' do
      expect(described_class.region_for(43.238, 76.945)).to be_nil # Almati (Qozog`iston)
      expect(described_class.region_for(45.0, 55.0)).to be_nil     # Orol dengizi g`arbi
    end

    it 'koordinata bo`sh bo`lsa -> nil' do
      expect(described_class.region_for(nil, 69.0)).to be_nil
      expect(described_class.region_for(41.0, nil)).to be_nil
    end
  end

  describe '.keys' do
    it 'aynan 14 ta O`zbekiston ma`muriy birligi' do
      expect(described_class.keys).to match_array(%w[
        qoraqalpogiston andijon buxoro fargona jizzax xorazm namangan navoiy
        qashqadaryo samarqand sirdaryo surxondaryo toshkent_viloyati toshkent_shahri
      ])
    end
  end

  describe '.display_name' do
    it 'mavjud locations.* lug`ati orqali joriy tilga tarjima qiladi' do
      expect(described_class.display_name('samarqand', locale: :uz)).to eq('Samarqand viloyati')
      expect(described_class.display_name('toshkent_shahri', locale: :ru)).to eq('город Ташкент')
      expect(described_class.display_name('qoraqalpogiston', locale: :en)).to eq('Republic of Karakalpakstan')
    end

    it 'bo`sh kalitda ""' do
      expect(described_class.display_name(nil)).to eq('')
    end
  end

  # Sof Ruby "nuqta ko`pburchak ichidami" — teshikli ko`pburchak sinovи.
  describe '.point_in_polygon?' do
    let(:square_with_hole) do
      [
        [[0, 0], [10, 0], [10, 10], [0, 10], [0, 0]],     # tashqi
        [[3, 3], [7, 3], [7, 7], [3, 7], [3, 3]]          # teshik
      ]
    end

    it 'tashqi halqa ichida, teshikdan tashqarida -> true' do
      expect(described_class.point_in_polygon?(1, 1, square_with_hole)).to be(true)
    end

    it 'teshik ichida -> false' do
      expect(described_class.point_in_polygon?(5, 5, square_with_hole)).to be(false)
    end

    it 'butunlay tashqarida -> false' do
      expect(described_class.point_in_polygon?(20, 20, square_with_hole)).to be(false)
    end
  end
end
