require 'aws-sdk'
require 'net/ssh'
require 'net/scp'
require 'colorize'
require 'tempfile'
require 'timeout'
require 'fileutils'

require 'distribution'

# Deals with an EC2 instance.
# http://docs.aws.amazon.com/AWSRubySDK/latest/frames.html
class Instance
  TAG_KEY = ENV.fetch('TAG_KEY') { 'pkgr-showcase-testing' }

  attr_reader :hostname, :user, :ec2_instance, :key_file

  def self.ec2
    AWS.ec2
  end

  def self.launch(distribution, tag_val = nil)
    ami_id = distribution.ami_id
    username = distribution.username

    tag_key = TAG_KEY
    tag_val ||= "#{distribution.name} - #{ami_id}"

    # attempt to find a running instance with the same tag
    ec2_instance = ec2.instances.tagged(tag_key).tagged_values(tag_val).select{|i| ["running"].include?(i.status.to_s)}.first

    key_name = "sandbox-key-#{`hostname -s`.chomp}"
    key_file = File.expand_path("~/.ssh/#{key_name}")

    puts "key_name=#{key_name} key_file=#{key_file}"

    # otherwise, create a new instance
    if ec2_instance.nil?
      puts "Launching a new instance..."
      # http://docs.aws.amazon.com/AWSRubySDK/latest/frames.html

      # re-create sandbox key
      key_pair = ec2.key_pairs.find{|k| k.name == key_name}
      unless key_pair
        key_pair = ec2.key_pairs.create(key_name)
        File.open(key_file, "wb") do |f|
          f.write(key_pair.private_key)
        end
        FileUtils.chmod 0600, key_file
      end

      fail "can't find #{key_file}" unless File.exists?(key_file)

      ec2_instance = ec2.instances.create(
        :image_id => ami_id,
        :instance_type => ENV.fetch('INSTANCE_TYPE') { distribution.instance_type },
        :subnet => ENV.fetch('INSTANCE_SUBNET') { "subnet-30db2569" },
        :security_group_ids => ENV.fetch('INSTANCE_SECURITY_GROUP_IDS') { 'sg-6e6f450b' }.split(","),
        :count => 1,
        :block_device_mappings => [{
          :device_name => distribution.root_device,
          :ebs => {
            :volume_size => distribution.volume_size,
            :delete_on_termination => true
          }
        }],
        :key_pair => ec2.key_pairs[key_name]
      )

      # give time for the instance to be created
      max_retries_attempts = 12
      until ec2_instance.status == :running
        if max_retries_attempts > 0
          max_retries_attempts -= 1
          sleep 10
        else
          raise "Instance is still not running. Aborting."
        end
      end

      ec2_instance.tags[tag_key] = tag_val
    else
      puts "Found an existing instance with #{tag_key}=#{tag_val.inspect}. Reusing..."
    end

    until ec2_instance.public_dns_name do
      sleep 2
    end

    vm = self.new(ec2_instance, ec2_instance.public_dns_name, username, key_file)

    if block_given?
      yield vm
      vm.destroy unless ENV['DEBUG'] == "yes"
    else
      vm
    end
  end

  def initialize(ec2_instance, hostname, user, key_file)
    @ec2_instance = ec2_instance
    @hostname, @user = hostname, user
    @key_file = key_file
  end

  def ssh(command = nil)
    command ||= Command.new("echo > /dev/null")

    puts "Attempting to connect to #{user}@#{hostname}..."

    tmpfile = Tempfile.new("command-script")
    tmpfile.write command.to_s
    tmpfile.close

    wait_for_ssh_readiness
    puts "SSH is ready"

    remaining_attempts = 10
    begin
      Net::SSH.start(*ssh_args) do |ssh|
        puts "Uploading runner..."
        ssh.scp.upload! tmpfile.path, "/tmp/runner"
        puts "Executing command..."

        cmd = command.sudo? ? "sudo bash /tmp/runner" : "bash /tmp/runner"

        ssh.open_channel do |ch|
          # handle requiretty clause in sudoers
          ch.request_pty do |ch, success|
            abort "could not obtain pty" unless success

            ch.exec("sudo sed -r -i 's|Defaults\s+requiretty||' /etc/sudoers") do |ch, success|
              abort "could not remove requiretty from sudoers file" unless success
              ch.on_data {|ch,data| puts data}
              ch.on_extended_data {|ch,data| puts data}
            end
          end
        end
        ssh.loop

        ssh.exec!(cmd) do |channel, stream, data|
          lines = data.split("\n")
          lines.each{|line| puts line.colorize(stream == :stdout ? :light_black : :light_red) }
        end

        yield ssh if block_given?
      end
    rescue Errno::ETIMEDOUT, Errno::ECONNREFUSED => e
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

  def destroy
    puts "Terminating instance..."
    ec2_instance.delete
  end

  private

  def ssh_args
    [hostname, user, {keys: [key_file], keys_only: true, paranoid: false}]
  end

  def wait_for_ssh_readiness
    # debian images can be VERY slow
    connection_remaining_attempts = 60
    authentication_remaining_attempts = 15

    begin
      Timeout.timeout(10) do
        Net::SSH.start(*ssh_args) do |ssh|
          ssh.exec!("ls")
        end
      end
    rescue Net::SSH::AuthenticationFailed => e
      # sometimes we get authentication failed, but it works a few seconds later
      if authentication_remaining_attempts > 0
        puts "Authentication failed, retrying for at most 3 times..."
        authentication_remaining_attempts -= 1
        sleep 10
        retry
      else
        raise e
      end
    rescue Timeout::Error, Errno::ETIMEDOUT, Errno::ECONNREFUSED => e
      if connection_remaining_attempts > 0
        puts "SSH not ready yet, retrying..."
        connection_remaining_attempts -= 1
        sleep 10
        retry
      else
        raise e
      end
    end

  end
end
