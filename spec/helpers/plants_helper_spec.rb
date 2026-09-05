require 'spec_helper'

describe PlantsHelper, type: :helper do
  describe '#sci_name_html' do
    # Band 9: "Acalypha australis" kursiv, "L." oddiy.
    it 'italicizes the genus + species and keeps a simple author plain' do
      html = helper.sci_name_html('Acalypha australis', 'L.')
      expect(html).to eq('<i>Acalypha australis</i> L.')
      expect(html).to be_html_safe
    end

    # Band 11: qavsli murakkab muallif ("(Bunge) Stef.") ham ODDIY.
    it 'keeps a parenthesized multi-part author plain' do
      html = helper.sci_name_html('Colchicum robustum', '(Bunge) Stef.')
      expect(html).to eq('<i>Colchicum robustum</i> (Bunge) Stef.')
    end

    # Band 12: "subsp."/"var." kabi rang belgilari ODDIY, undan keyingi
    # epitet esa yana KURSIV bo'lishi kerak.
    it 'keeps infraspecific rank markers plain and italicizes the epithet after them' do
      html = helper.sci_name_html('Arnebia decumbens subsp. decumbens')
      expect(html).to eq('<i>Arnebia decumbens</i> subsp. <i>decumbens</i>')
    end

    it 'handles a species with no author at all' do
      html = helper.sci_name_html('Eremurus baissunensis', 'O.Fedtsch.')
      expect(html).to eq('<i>Eremurus baissunensis</i> O.Fedtsch.')
    end

    it 'parses a combined species_sci-style string (name + author together) the same way' do
      html = helper.sci_name_html('Acalypha australis L.')
      expect(html).to eq('<i>Acalypha australis</i> L.')
    end

    it 'handles a hybrid marker between genus and species' do
      html = helper.sci_name_html('Psylliostachys x androssovii', 'Roshkova')
      expect(html).to eq('<i>Psylliostachys</i> x <i>androssovii</i> Roshkova')
    end

    it 'escapes raw HTML in the input (XSS safety)' do
      html = helper.sci_name_html('<script>alert(1)</script> foo', 'L.')
      expect(html).not_to include('<script>')
      expect(html).to include('&lt;script&gt;')
    end

    it 'returns an empty safe string for blank input' do
      html = helper.sci_name_html('')
      expect(html).to eq('')
      expect(html).to be_html_safe
    end
  end

  describe '#genus_name_html' do
    it 'italicizes a bare genus name' do
      expect(helper.genus_name_html('Ophioglossum')).to eq('<i>Ophioglossum</i>')
    end

    it 'keeps an author attached to a genus-only value plain' do
      expect(helper.genus_name_html('Ophioglossum L.')).to eq('<i>Ophioglossum</i> L.')
    end
  end

  describe '#plant_sci_name_html' do
    it 'prefers accepted_name + accepted_authors when present' do
      plant = Plant.new(species_sci: 'Old name Ignored', accepted_name: 'Colchicum robustum', accepted_authors: 'Stef.')
      expect(helper.plant_sci_name_html(plant)).to eq('<i>Colchicum robustum</i> Stef.')
    end

    it 'falls back to parsing species_sci when accepted_name is blank' do
      plant = Plant.new(species_sci: 'Acalypha australis L.')
      expect(helper.plant_sci_name_html(plant)).to eq('<i>Acalypha australis</i> L.')
    end
  end
end
