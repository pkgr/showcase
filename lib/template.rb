require 'erb'
require 'ostruct'

class Template
  class Context < OpenStruct
    def sesame
      binding
    end
  end

  attr_reader :path, :context

  def initialize(path, opts = {})
    @context = Context.new(opts)
    @path = File.expand_path(path)
  end

  def render
    ERB.new(File.read(path)).result(context.sesame)
  end
end
