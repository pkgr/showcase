require 'aws-sdk'
require 'rspec'
require 'capybara/rspec'

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require 'command'
require 'instance'
require 'template'

Capybara.default_driver = :selenium
Capybara.run_server = false

AWS.config(
  access_key_id: ENV.fetch('AWS_ACCESS_KEY'),
  secret_access_key: ENV.fetch('AWS_SECRET_KEY'),
  region: 'us-east-1'
)

def data_file(path)
  File.expand_path("../../data/#{path}", __FILE__)
end

def wait_until(timeout = 60, &block)
  Timeout.timeout(timeout) do
    until block.call do
      sleep 5
    end
  end
end

RSpec.configure do |config|
  config.include Capybara::DSL

  config.before(:suite) do
  end

  config.before(:each) do
  end

  config.after(:each) do
  end

  config.order = "random"
end
