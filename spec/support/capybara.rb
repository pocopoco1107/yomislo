require "capybara/rspec"

RSpec.configure do |config|
  config.include Capybara::DSL, type: :system

  config.before(:each, type: :system) do
    driven_by :rack_test
  end
end
