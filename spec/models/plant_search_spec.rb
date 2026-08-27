require 'spec_helper'

# 2026-08-27: mualliflar bilan (accepted_authors) va guruh (primary_record)
# bilan bog'liq ketma-ket ikkita xato aniqlangach yozilgan. Maqsad: bu
# ssenariylar QAYTIB kelmasin.
describe Plant, type: :model do
  describe '.search' do
    let!(:colchicum_accepted) do
      Plant.create!(
        species_sci: 'Merendera hissarica Regel',
        species_uz: 'Hisor sangrayqulog\'i', species_ru: 'мерендера гиссарская',
        family_lat: 'Colchicaceae', genus_lat: 'Merendera',
        accepted_name: 'Colchicum robustum', accepted_authors: '(Bunge) Stef.',
        accepted_family: 'Colchicaceae', accepted_genus: 'Colchicum',
        wcvp_status: 'Synonym', primary_record: true
      )
    end
    let!(:colchicum_synonym) do
      Plant.create!(
        species_sci: 'Merendera robusta Bunge',
        species_uz: 'yirik sangrayquloq', species_ru: 'мерендера крупная',
        family_lat: 'Colchicaceae', genus_lat: 'Merendera',
        accepted_name: 'Colchicum robustum', accepted_authors: '(Bunge) Stef.',
        accepted_family: 'Colchicaceae', accepted_genus: 'Colchicum',
        wcvp_status: 'Synonym', primary_record: false
      )
    end
    let!(:colchicum_other_species) do
      Plant.create!(
        species_sci: 'Colchicum luteum Baker', species_uz: 'sariq savrinjon',
        family_lat: 'Colchicaceae', genus_lat: 'Colchicum',
        accepted_name: 'Colchicum luteum', accepted_authors: 'Baker',
        accepted_family: 'Colchicaceae', accepted_genus: 'Colchicum',
        wcvp_status: 'Accepted', primary_record: true
      )
    end

    # Ekran to'liq ko'rsatadigan nom (species_sci EMAS, accepted_name +
    # accepted_authors) bo'yicha qidiruv — asosiy xato shu edi.
    it 'finds a plant by its full displayed name including authors' do
      expect(Plant.search('Colchicum robustum (Bunge) Stef.')).to include(colchicum_accepted)
    end

    it 'finds a plant by accepted name without authors' do
      expect(Plant.search('Colchicum robustum')).to include(colchicum_accepted)
    end

    it 'finds plants by genus alone (multiple results)' do
      result = Plant.search('Colchicum')
      expect(result).to include(colchicum_accepted, colchicum_other_species)
    end

    it 'finds a plant by its old (synonym) name plus author' do
      expect(Plant.search('Merendera robusta Bunge')).to contain_exactly(colchicum_synonym)
    end

    it 'finds a plant by an old synonym name alone' do
      expect(Plant.search('Merendera hissarica')).to contain_exactly(colchicum_accepted)
    end

    it 'finds a plant by its Uzbek name' do
      expect(Plant.search('yirik sangrayquloq')).to contain_exactly(colchicum_synonym)
    end

    it 'finds a plant with mixed unrelated word fragments across columns' do
      expect(Plant.search('robustum Stef')).to include(colchicum_accepted)
    end

    it 'returns every plant for a blank query' do
      expect(Plant.search('').count).to eq(Plant.count)
      expect(Plant.search('   ').count).to eq(Plant.count)
    end

    it 'is not vulnerable to LIKE wildcard injection via % or _' do
      Plant.create!(species_sci: 'Xylonimus underscoreus', primary_record: true)
      expect(Plant.search('robust_m')).to be_empty
    end
  end

  describe '.group_search' do
    let!(:accepted_member) do
      Plant.create!(
        species_sci: 'Merendera hissarica Regel', species_uz: 'Hisor sangrayqulog\'i',
        accepted_name: 'Colchicum robustum', accepted_authors: '(Bunge) Stef.',
        wcvp_status: 'Synonym', primary_record: true
      )
    end
    let!(:hidden_member) do
      Plant.create!(
        species_sci: 'Merendera robusta Bunge', species_uz: 'yirik sangrayquloq',
        accepted_name: 'Colchicum robustum', accepted_authors: '(Bunge) Stef.',
        wcvp_status: 'Synonym', primary_record: false
      )
    end

    # Asosiy 2-xato: primary bo'lmagan a'zoni (masalan eski nom) qidirilsa,
    # natija uning PRIMARY vakiliga olib kelishi kerak, aks holda hech
    # narsa topilmas edi.
    it "redirects a match on a non-primary group member to its primary" do
      scope = Plant.where(primary_record: true).merge(Plant.group_search('Merendera robusta'))
      expect(scope).to contain_exactly(accepted_member)
    end

    it 'does not duplicate the primary when both it and a hidden sibling match' do
      scope = Plant.where(primary_record: true).merge(Plant.group_search('Colchicum robustum'))
      expect(scope.to_a.uniq).to eq(scope.to_a)
      expect(scope).to contain_exactly(accepted_member)
    end

    it 'keeps independently-listed group members (exceptions) as separate results' do
      domestica = Plant.create!(species_sci: 'Malus domestica L.', accepted_name: 'Malus domestica', wcvp_status: 'Accepted', primary_record: true)
      sieversii = Plant.create!(species_sci: 'Malus sieversii (Ledeb.) M. Roem', accepted_name: 'Malus domestica', wcvp_status: 'Synonym', primary_record: true)

      scope = Plant.where(primary_record: true).merge(Plant.group_search('Malus'))
      expect(scope).to include(domestica, sieversii)
      expect(scope.to_a.uniq).to eq(scope.to_a)
    end
  end
end
