require 'aws-sdk'
require 'rspec'
require 'erb'
require 'capybara/rspec'

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require 'command'
require 'instance'

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

def template_for(filepath, attributes = {})
  domain = OpenStruct.new(attributes)
  def domain.sesame
    binding
  end

  ERB.new(File.read(data_file(filepath))).result(domain.sesame)
end

def codename_for(distribution)
  case distribution
  when "debian-7"
    "wheezy"
  when "ubuntu-12.04"
    "precise"
  when "ubuntu-14.04"
    "trusty"
  else
    raise "don't know the codename mapping for #{distribution}"
  end
end


def ec2_launch(distribution, tag_val = nil)
  ami_id = case distribution
  when "debian-7"
    "ami-3776795e"
  when "ubuntu-12.04"
    "ami-0b9c9f62"
  when "ubuntu-14.04"
    "ami-018c9568"
  else
    raise "don't know how to launch ec2 vm for #{distribution}"
  end

  tag_key = 'pkgr-showcase-testing'
  tag_val ||= "#{distribution} - #{ami_id}"

  username = case distribution
  when /ubuntu/
    "ubuntu"
  when /debian/
    "admin"
  else
    "root"
  end

  ec2 = AWS.ec2

  # attempt to find a running instance with the same tag
  ec2_instance = ec2.instances.tagged(tag_key).tagged_values(tag_val).select{|i| ["running"].include?(i.status.to_s)}.first

  # otherwise, create a new instance
  if ec2_instance.nil?
    puts "Launching a new instance..."
    # http://docs.aws.amazon.com/AWSRubySDK/latest/frames.html
    ec2_instance = ec2.instances.create(
      :image_id => ami_id,
      :instance_type => 't1.micro',
      :count => 1,
      :security_groups => 'default',
      :key_pair => ec2.key_pairs['aws']
    )
    ec2_instance.tags[tag_key] = tag_val
  else
    puts "Found an existing instance with #{tag_key}=#{tag_val.inspect}. Reusing..."
  end

  until ec2_instance.public_dns_name do
    sleep 1
  end

  vm = Instance.new(ec2_instance, ec2_instance.public_dns_name, username)

  if block_given?
    yield vm
    vm.destroy unless ENV['DEBUG'] == "yes"
  else
    vm
  end
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

  # config.order = "random"
end
