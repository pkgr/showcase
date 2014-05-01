require 'net/ssh'
require 'net/scp'
require 'colorize'
require 'tempfile'
require 'timeout'

# Deals with an EC2 instance.
# http://docs.aws.amazon.com/AWSRubySDK/latest/frames.html
class Instance
  attr_reader :hostname, :user, :ec2_instance

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
    remaining_attempts = 20

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
