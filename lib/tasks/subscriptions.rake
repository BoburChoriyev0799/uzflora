namespace :big_years do
  #TODO: generate year subscription for new year and delete subscription for previous year if there isn't any photo of user in BY
  #(this task will do transition from on old year to new year)
  desc 'Generate year subscription for all participant of BigYear for current_year'
  task :gen_subscriptions, [:year] => :environment do |t, args|
    count = 0
    current_year = args.year
    User.where(big_year: true).each do |user|
      count = count + 1 if user.subscribe!(current_year)
    end
    Rails.logger.info("#{Time.zone.now}: Task big_year:gen_subscriptions has generated #{count} subscription for BigYear #{current_year}!")
  end
end
