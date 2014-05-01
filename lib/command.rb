class Command
  attr_reader :io, :sudo

  def initialize(io, opts = {})
    @io = io
    @sudo = opts.key?(:sudo) ? opts[:sudo] : false
  end

  def sudo?
    sudo
  end

  def to_s
    case io
    when IO
      io.read
    else
      io.to_s
    end
  end
end
