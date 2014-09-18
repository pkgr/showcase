require 'aws-sdk'
require 'rspec'
require 'capybara/rspec'

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require 'command'
require 'instance'
require 'template'

Capybara.default_driver = :selenium
Capybara.run_server = false
# since we're cold-loading the apps most of the time, it makes sense to wait more
Capybara.default_wait_time = 10

AWS.config(
  access_key_id: ENV.fetch('AWS_ACCESS_KEY'),
  secret_access_key: ENV.fetch('AWS_SECRET_KEY'),
  region: ENV.fetch('AWS_REGION') { 'us-east-1' }
)

def data_file(path)
  File.expand_path("../../data/#{path}", __FILE__)
end

def distributions
  ENV.fetch('DISTRIBUTIONS') { "debian-7,ubuntu-12.04,ubuntu-14.04" }.split(",").map{|d| Distribution.new(d) }
end

def branch
  ENV.fetch('BRANCH') { "pkgr" }
end

def wait_until(timeout = 180, &block)
  Timeout.timeout(timeout) do
    until block.call do
      sleep 10
    end
  end
end

RSpec.configure do |config|
  config.include Capybara::DSL
  config.order = "random"

  config.after(:suite) do
    running_instances = AWS.ec2.instances.tagged(Instance::TAG_KEY).select{|i| ["running"].include?(i.status.to_s)}
    puts "Some instances are still running: #{running_instances.collect(&:id)}" if running_instances.any?
    running_instances.each(&:delete) unless ENV['DEBUG'] == "yes"
  end
end
