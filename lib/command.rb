class Command
  attr_reader :io, :sudo

  def initialize(io, opts = {})
    @io = io
    @sudo = opts.key?(:sudo) ? opts[:sudo] : false
    @dry_run = opts.key?(:dry_run) ? opts[:dry_run] : false
  end

  def sudo?
    sudo
  end

  def dry_run?
    @dry_run
  end

  def to_s
    if dry_run?
      "echo DRY_RUN"
    else
      case io
      when IO
        io.read
      else
        io.to_s
      end
    end
  end
end
