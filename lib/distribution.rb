class Distribution
  attr_reader :name

  def initialize(name)
    @name = name
  end

  def ami_id
    case name
    when "debian-7"
      "ami-e0efab88" # hvm
    when "debian-8"
      "ami-144f4d7c" # hvm
    when "ubuntu-12.04"
      "ami-1eab0176" # hvm
      # "ami-0b9c9f62"
    when "ubuntu-14.04"
      "ami-8afb51e2" # hvm
      # "ami-018c9568"
    when "fedora-20"
      # "ami-6e7da906" # hvm
      "ami-1337187a"
    when "centos-6"
      "ami-eec75e87" # hvm
    when "rhel-6"
      "ami-5b697332"
    when "sles-12"
      "ami-aeb532c6" # hvm
    else
      raise "don't know how to launch ec2 vm for #{distribution}"
    end
  end

  def username
    case name
    when /ubuntu/
      "ubuntu"
    when /debian/
      "admin"
    when /fedora/
      "fedora"
    when /centos/, /rhel/, /sles/
      "ec2-user"
    else
      "root"
    end
  end

  def codename
    case name
    when "debian-7"
      "wheezy"
    when "debian-8"
      "jessie"
    when "ubuntu-12.04"
      "precise"
    when "ubuntu-14.04"
      "trusty"
    when "fedora-20"
      "fedora20"
    when "centos-6", "rhel-6"
      "centos6"
    when "sles-12"
      "sles12"
    else
      raise "don't know the codename mapping for #{distribution}"
    end
  end

  def osfamily
    case name
    when /debian/, /ubuntu/
      "debian"
    when /fedora/, /redhat/, /centos/, /rhel/
      "redhat"
    when /sles/
      "suse"
    end
  end

  def root_device
    case osfamily
    when "debian"
      "/dev/xvda"
    when "redhat", "suse"
      "/dev/sda1"
    else
      fail "no root_device set"
    end
  end

  def instance_type
    case name
    when /fedora/
      "m1.small"
    else
      "t2.micro"
    end
  end

end
