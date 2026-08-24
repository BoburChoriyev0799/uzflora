require 'spec_helper'
require 'statistics/big_year'

describe Statistics::BigYear do
  let(:current_year) { Time.zone.now.year }

  describe '.users_count' do
    let!(:user1) { FactoryBot.create :user }
    let!(:user1_subscription1) { FactoryBot.create :subscription, user: user1, year: current_year - 1 }
    let!(:user1_subscription2) { FactoryBot.create :subscription, user: user1, year: current_year }

    let!(:user2) { FactoryBot.create :user }

    let!(:user3) { FactoryBot.create :user }
    let!(:user3_subscription) { FactoryBot.create :subscription, user: user3, year: 2.years.ago.year }

    let!(:user4) { FactoryBot.create :user }
    let!(:user4_subscription) { FactoryBot.create :subscription, user: user4, year: current_year }

    it 'returns amount of BigYear participants for all years' do
      expect(described_class.users_count).to eq(3)
    end
  end
end
