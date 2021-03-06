class Distribution
  attr_reader :name

  def initialize(name)
    @name = name
  end

  def volume_size
    case name
    when "sles-11", "sles-12"
      50 # sles-11 ami needs more inodes that the default, and adding more storage increases it
    else
      10 # 10 GiB
    end
  end

  def ami_id
    case name
    when "debian-7"
      "ami-e0efab88" # hvm
    when "debian-8"
      "ami-144f4d7c" # hvm
    when "debian-9"
      "ami-27072e31"
    when "ubuntu-12.04"
      "ami-1eab0176" # hvm
      # "ami-0b9c9f62"
    when "ubuntu-14.04"
      "ami-8afb51e2" # hvm
      # "ami-018c9568"
    when "ubuntu-16.04"
      "ami-13be557e" # hvm
    when "fedora-20"
      # "ami-6e7da906" # hvm
      "ami-21362b48"
    when "centos-6", "el-6"
      # "ami-eec75e87" # hvm
      "ami-57cd8732" # hvm
    when "centos-7", "el-7"
      "ami-96a818fe" # hvm
    when "rhel-6"
      "ami-5b697332"
    when "sles-12"
      "ami-aeb532c6" # hvm
    when "sles-11"
      "ami-3bf32750" # hvm
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
    when "centos-7", "el-7"
      "centos"
    when "centos-6", "el-6"
      "centos"
    when /rhel/, /sles/
      "ec2-user"
    else
      "root"
    end
  end

  def codename
    return name.sub("-", "/")
    case name
    when "debian-7"
      "wheezy"
    when "debian-8"
      "jessie"
    when "debian-9"
      "stretch"
    when "ubuntu-12.04"
      "precise"
    when "ubuntu-14.04"
      "trusty"
    when "ubuntu-16.04"
      "xenial"
    when "fedora-20"
      "fedora20"
    when "centos-6", "rhel-6"
      "centos6"
    when "centos-7"
      "centos7"
    when "sles-12"
      "sles12"
    when "sles-11"
      "sles11"
    else
      raise "don't know the codename mapping for #{distribution}"
    end
  end

  def el?
    osfamily == "redhat"
  end

  def suse?
    osfamily == "suse"
  end

  def debian?
    osfamily == "debian"
  end

  def osfamily
    case name
    when /debian/, /ubuntu/
      "debian"
    when /fedora/, /redhat/, /centos/, /rhel/, /el/
      "redhat"
    when /sles/
      "suse"
    else
      fail "unknown osfamily for #{name.inspect}"
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
      "t2.small"
    end
  end

end
