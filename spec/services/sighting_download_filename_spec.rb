require 'spec_helper'

# 2-ish (2f): kuzatuv rasmini yuklab olishda fayl nomi — ilmiy nom bilan.
describe SightingDownloadFilename do
  describe '.for' do
    def sighting_double(plant:, id: 113, timestamp: Time.zone.local(2026, 8, 24), extension: 'jpg')
      photo_file = double(extension: extension)
      photo = double(file: photo_file)
      double(plant: plant, id: id, timestamp: timestamp, created_at: timestamp, photo: photo)
    end

    it 'turkum_tur_sana_id formatida hosil qiladi, muallif qisqartmasi tushmaydi' do
      plant = double(accepted_name: nil, species_sci: 'Capparis spinosa L.')
      sighting = sighting_double(plant: plant, id: 113, timestamp: Time.zone.local(2026, 8, 24))
      expect(described_class.for(sighting)).to eq('Capparis_spinosa_2026-08-24_uzflora-113.jpg')
    end

    it '"L." yoki murakkab muallif qisqartmasi ("(Boiss.) Boiss.") fayl nomiga TUSHMAYDI' do
      plant = double(accepted_name: nil, species_sci: 'Zygophyllum fabago (Boiss.) Boiss.')
      sighting = sighting_double(plant: plant)
      name = described_class.for(sighting)
      expect(name).not_to match(/Boiss/)
      expect(name).not_to match(/\bL\b/)
      expect(name).to start_with('Zygophyllum_fabago_')
    end

    it 'accepted_name (POWO, muallifsiz) mavjud bo`lsa ustuvor ishlatiladi' do
      plant = double(accepted_name: 'Tulipa korolkovii', species_sci: 'Tulipa korolkowii Regel')
      sighting = sighting_double(plant: plant)
      expect(described_class.for(sighting)).to start_with('Tulipa_korolkovii_')
    end

    it 'tur aniqlanmagan (plant nil) bo`lsa "aniqlanmagan_..." bo`ladi' do
      sighting = sighting_double(plant: nil)
      expect(described_class.for(sighting)).to eq('aniqlanmagan_2026-08-24_uzflora-113.jpg')
    end

    it 'diakritik/apostrof belgilari ASCII`ga keltiriladi' do
      plant = double(accepted_name: nil, species_sci: "Fargʻona test L.")
      sighting = sighting_double(plant: plant)
      expect(described_class.for(sighting)).to start_with('Fargona_test_')
    end

    it 'duragay ("×"/"x") belgisi hisobga olinadi — 3-so`z ham olinadi' do
      plant = double(accepted_name: nil, species_sci: 'Psylliostachys x androssovii Roshkova')
      sighting = sighting_double(plant: plant)
      expect(described_class.for(sighting)).to start_with('Psylliostachys_x_androssovii_')
    end

    it 'chiziqcha bilan yozilgan epitet ("caput-medusae") saqlanadi' do
      plant = double(accepted_name: nil, species_sci: 'Calligonum caput-medusae Schrenk')
      sighting = sighting_double(plant: plant)
      expect(described_class.for(sighting)).to start_with('Calligonum_caput-medusae_')
    end

    it 'xavfli belgilar ("/", "\\", "..") fayl nomiga hech qachon tushmaydi' do
      plant = double(accepted_name: nil, species_sci: "../../etc/passwd\\ L.")
      sighting = sighting_double(plant: plant)
      name = described_class.for(sighting)
      expect(name).not_to include('/')
      expect(name).not_to include('\\')
      expect(name).not_to include('..')
    end

    it 'kengaytma asl fayldan olinadi (png)' do
      plant = double(accepted_name: nil, species_sci: 'Rosa canina L.')
      sighting = sighting_double(plant: plant, extension: 'png')
      expect(described_class.for(sighting)).to end_with('.png')
    end

    it 'noma`lum/ruxsat etilmagan kengaytma bo`lsa jpg`ga tushadi' do
      plant = double(accepted_name: nil, species_sci: 'Rosa canina L.')
      sighting = sighting_double(plant: plant, extension: 'exe')
      expect(described_class.for(sighting)).to end_with('.jpg')
    end
  end

  describe '.sanitize' do
    it 'faqat harf/raqam/pastki chiziq/chiziqchani qoldiradi' do
      expect(described_class.sanitize('Élaeagnus angustifólia')).to eq('Elaeagnus_angustifolia')
    end

    it 'bo`sh natija bo`lsa "aniqlanmagan"ga tushadi' do
      expect(described_class.sanitize('***')).to eq('aniqlanmagan')
    end
  end
end
