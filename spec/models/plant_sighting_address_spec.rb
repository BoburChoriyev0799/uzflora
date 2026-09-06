require 'spec_helper'

describe PlantSighting, type: :model do
  let(:user) { FactoryBot.create(:user) }

  describe 'address whitespace hygiene (before_save)' do
    def build(address)
      PlantSighting.new(user: user, published: false, status: 'pending', address: address)
    end

    it 'trims leading/trailing whitespace on save' do
      sighting = build('  Toshkent  ')
      sighting.save!
      expect(sighting.address).to eq('Toshkent')
    end

    it 'collapses runs of inner whitespace to a single space' do
      sighting = build("Toshkent    shahri\tmarkazi")
      sighting.save!
      expect(sighting.address).to eq('Toshkent shahri markazi')
    end

    it 'stores nil when the address is only whitespace' do
      sighting = build("   \n ")
      sighting.save!
      expect(sighting.address).to be_nil
    end

    it 'never alters the textual content, only spacing' do
      sighting = build(' Quyi  Amudaryo Davlat  Biosfera Rezervati ')
      sighting.save!
      expect(sighting.address).to eq('Quyi Amudaryo Davlat Biosfera Rezervati')
    end
  end
end
