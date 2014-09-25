class Distribution
  attr_reader :name

  def initialize(name)
    @name = name
  end

  def ami_id
    case name
    when "debian-7"
      "ami-86896dee" # hvm
      # "ami-3776795e"
    when "ubuntu-12.04"
      "ami-1eab0176" # hvm
      # "ami-0b9c9f62"
    when "ubuntu-14.04"
      "ami-8afb51e2" # hvm
      # "ami-018c9568"
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
    else
      "root"
    end
  end

  def codename
    case name
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
end
