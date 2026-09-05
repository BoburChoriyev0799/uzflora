require 'spec_helper'

describe TextHelper, type: :helper do
  describe '#capitalize_first' do
    # Band 4: "Life form: annual" -> "Life form: Annual" — faqat
    # BIRINCHI harf bosh harfga aylanadi.
    it 'capitalizes only the first letter' do
      expect(helper.capitalize_first('annual')).to eq('Annual')
    end

    # Band 6: vergul bilan ajratilgan ro'yxatda faqat BIRINCHI so'z
    # bosh harfda bo'lishi kerak, qolganlari kichik qoladi.
    it 'leaves the rest of a comma-separated list untouched' do
      expect(helper.capitalize_first('medicinal, oil-bearing')).to eq('Medicinal, oil-bearing')
    end

    # Band 5: kirill harflarida ham to'g'ri ishlashi kerak (oddiy
    # `String#capitalize` kirillda ishlamaydi).
    it 'works correctly for Cyrillic text' do
      expect(helper.capitalize_first('акалифа австралийская')).to eq('Акалифа австралийская')
    end

    it 'is a no-op for blank input' do
      expect(helper.capitalize_first(nil)).to be_nil
      expect(helper.capitalize_first('')).to eq('')
    end

    it 'does not change an already-capitalized string' do
      expect(helper.capitalize_first('Annual')).to eq('Annual')
    end
  end
end
