class PagesController < ApplicationController
  def donation
    @donation = Donation.new(amount: 20_000, payment_method: 'payme')
  end
end
