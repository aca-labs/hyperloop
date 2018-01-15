require "logger"
require "habitat"

class TaggedLogger::Logger < Logger
  Habitat.create do
    setting log_tags : Array(Proc(String)) = [] of Proc(String)
  end

  def initialize(@io : IO? = STDOUT)
    super(@io)
    @tags = [] of String
  end

  def tagged(*args)
    @tags.concat args
    yield self.as(TaggedLogger::Logger)
    @tags.pop args.size
  end

  private def write(severity, datetime, progname, message)
    ltags = settings.log_tags
    tags = if !ltags.empty?
             ltags.map { |p| p.call }.reject!(&.empty?).concat(@tags)
           else
             @tags
           end

    if tags.empty?
      super(severity, datetime, progname, message)
    else
      super(severity, datetime, progname, "[#{tags.join("] [")}] #{message.to_s}")
    end
  end
end
