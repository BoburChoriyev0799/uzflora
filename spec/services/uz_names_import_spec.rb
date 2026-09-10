require 'spec_helper'

describe UzNamesImport do
  let!(:primary) do
    Plant.create!(species_sci: 'Tulipa importa Regel', accepted_name: 'Tulipa importa', primary_record: true)
  end
  let!(:member) do
    Plant.create!(species_sci: 'Tulipa synonyma Bunge', accepted_name: 'Tulipa importa',
                  wcvp_status: 'Synonym', primary_record: false)
  end
  let!(:other) { Plant.create!(species_sci: 'Rosa alia L.', primary_record: true) }

  def csv(*rows)
    hdr = 'id,lotincha_nom,qabul_qilingan_nom,oila,ruscha_nom,qoraqalpoqcha_nom,qizil_kitob,kuzatuvlar_soni,species_uz'
    ([ hdr ] + rows).join("\n")
  end

  describe '.plan' do
    it 'id bo`yicha moslashadi, guruhning barcha a`zolarini yozishga qo`yadi' do
      plan = described_class.plan(csv("#{primary.id},x,,,,,,,oq lola"))
      expect(plan.added).to eq(1)
      expect(plan.to_write).to eq(primary.id => 'oq lola', member.id => 'oq lola')
    end

    it 'bo`sh species_uz qatorni sanaydi, yozmaydi' do
      plan = described_class.plan(csv("#{primary.id},x,,,,,,,", "#{other.id},y,,,,,,, "))
      expect(plan.skipped_blank).to eq(2)
      expect(plan.to_write).to be_empty
    end

    it 'mavjud species_uz ustiga yozmaydi -> conflict' do
      primary.update_column(:species_uz, 'eski')
      plan = described_class.plan(csv("#{primary.id},x,,,,,,,yangi"))
      expect(plan.conflicts.first).to include(id: primary.id, existing: 'eski', csv: 'yangi')
      expect(plan.to_write).to be_empty
    end

    it 'id topilmasa not_found' do
      plan = described_class.plan(csv('99999999,x,,,,,,,nom'))
      expect(plan.not_found_ids).to eq([ '99999999' ])
    end

    it 'idempotent — qiymat allaqachon bo`lsa `already`' do
      described_class.apply!(described_class.plan(csv("#{primary.id},x,,,,,,,oq lola")))
      plan = described_class.plan(csv("#{primary.id},x,,,,,,,oq lola"))
      expect(plan.added).to eq(0)
      expect(plan.already).to eq(1)
    end

    it 'kerakli ustun yo`q bo`lsa InvalidFile' do
      expect { described_class.plan("lotincha_nom,species_uz\nA,b") }
        .to raise_error(UzNamesImport::InvalidFile, /id/)
    end

    it 'buzuq CSV -> InvalidFile (500 emas)' do
      expect { described_class.plan("id,species_uz\n1,\"yopilmagan") }
        .to raise_error(UzNamesImport::InvalidFile)
    end
  end

  describe '.apply!' do
    it 'plan.to_write ni bitta transaction`da yozadi va sonini qaytaradi' do
      plan = described_class.plan(csv("#{primary.id},x,,,,,,,oq lola"))
      expect(described_class.apply!(plan)).to eq(2)
      expect(primary.reload.species_uz).to eq('oq lola')
      expect(member.reload.species_uz).to eq('oq lola')
    end

    it 'bo`sh planда hech narsa yozmaydi' do
      plan = described_class.plan(csv("#{primary.id},x,,,,,,,"))
      expect { described_class.apply!(plan) }.not_to(change { primary.reload.updated_at })
    end
  end
end
