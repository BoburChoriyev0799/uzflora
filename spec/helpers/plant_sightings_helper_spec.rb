require 'spec_helper'

describe PlantSightingsHelper, type: :helper do
  describe '#normalize_location_key' do
    it 'collapses case, trailing/leading space and inner space to one key' do
      %w[Toshkent toshkent].each do |v|
        expect(helper.normalize_location_key(v)).to eq('toshkent')
      end
      expect(helper.normalize_location_key('Toshkent ')).to eq('toshkent')
      expect(helper.normalize_location_key(' TOSHKENT ')).to eq('toshkent')
    end

    it 'drops every apostrophe variant' do
      keys = ["Farg'ona", 'Fargʻona', 'Farg‘ona', 'Farg’ona', 'Fargʼona', 'Farg`ona']
        .map { |v| helper.normalize_location_key(v) }
      expect(keys.uniq).to eq(['fargona'])
    end

    it 'drops dashes, dots and commas, keeping only letters and digits' do
      expect(helper.normalize_location_key('Ug\'am-Chotqol milliy tabiat bog\'i'))
        .to eq('ugamchotqolmilliytabiatbogi')
    end
  end

  describe '#translate_location' do
    it 'maps every Tashkent spelling to the Russian dictionary value' do
      I18n.with_locale(:ru) do
        ['Toshkent', 'Toshkent ', 'toshkent', ' TOSHKENT '].each do |raw|
          expect(helper.translate_location(raw)).to eq('Ташкент')
        end
      end
    end

    it 'translates the real reserve value found in production' do
      I18n.with_locale(:ru) do
        expect(helper.translate_location('Quyi Amudaryo Davlat Biosfera Rezervati'))
          .to eq('Нижне-Амударьинский государственный биосферный резерват')
      end
    end

    it 'returns the raw text verbatim (capitalized) in every locale when not in the dictionary' do
      %i[uz ru en].each do |locale|
        I18n.with_locale(locale) do
          expect(helper.translate_location("Falon-Filon qishlog'i")).to eq("Falon-Filon qishlog'i")
        end
      end
    end

    it 'never emits a translation-missing marker or a bare key' do
      I18n.with_locale(:en) do
        result = helper.translate_location('Notinthelist joyi')
        expect(result).not_to match(/translation missing/i)
        expect(result).not_to start_with('locations.')
      end
    end

    it 'returns an empty string for nil and blank without raising' do
      expect(helper.translate_location(nil)).to eq('')
      expect(helper.translate_location('')).to eq('')
      expect(helper.translate_location('   ')).to eq('')
    end

    it 'yields one result for all apostrophe variants of the same name' do
      I18n.with_locale(:uz) do
        results = ["Farg'ona", 'Fargʻona', 'Farg‘ona'].map { |v| helper.translate_location(v) }
        expect(results.uniq).to eq(["Farg'ona"])
      end
    end
  end
end
