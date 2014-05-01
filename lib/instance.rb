require 'aws-sdk'
require 'net/ssh'
require 'net/scp'
require 'colorize'
require 'tempfile'
require 'timeout'

require 'distribution'

# Deals with an EC2 instance.
# http://docs.aws.amazon.com/AWSRubySDK/latest/frames.html
class Instance
  attr_reader :hostname, :user, :ec2_instance

  def self.ec2
    AWS.ec2
  end

  def self.launch(distribution, tag_val = nil)
    ami_id = distribution.ami_id
    username = distribution.username

    tag_key = 'pkgr-showcase-testing'
    tag_val ||= "#{distribution.name} - #{ami_id}"

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
      sleep 2
    end

    vm = self.new(ec2_instance, ec2_instance.public_dns_name, username)

    if block_given?
      yield vm
      vm.destroy unless ENV['DEBUG'] == "yes"
    else
      vm
    end
  end

  def initialize(ec2_instance, hostname, user)
    @ec2_instance = ec2_instance
    @hostname, @user = hostname, user
  end

  def ssh(command = nil)
    command ||= Command.new("echo > /dev/null")

    puts "Attempting to connect to #{user}@#{hostname}..."

    tmpfile = Tempfile.new("command-script")
    tmpfile.write command.to_s
    tmpfile.close

    wait_for_ssh_readiness

    Net::SSH.start(hostname, user) do |ssh|
      puts "Uploading runner..."
      ssh.scp.upload! tmpfile.path, "/tmp/runner"
      puts "Executing command..."

      cmd = command.sudo? ? "sudo bash /tmp/runner" : "bash /tmp/runner"

      ssh.exec!(cmd) do |channel, stream, data|
        lines = data.split("\n")
        lines.each{|line| puts line.colorize(stream == :stdout ? :light_black : :light_red) }
      end

      yield ssh if block_given?
    end
  end

  def destroy
    puts "Terminating instance..."
    ec2_instance.delete
  end

  private
  def wait_for_ssh_readiness
    # debian images can be VERY slow
    remaining_attempts = 30

    begin
      Timeout.timeout(10) do
        Net::SSH.start(hostname, user) do |ssh|
          ssh.exec!("ls")
        end
      end
    rescue Timeout::Error, Errno::ECONNREFUSED => e
      if remaining_attempts > 0
        puts "SSH not ready yet, retrying..."
        remaining_attempts -= 1
        sleep 5
        retry
      else
        raise e
      end
    end

  end
end
