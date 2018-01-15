require "./spec_helper"
require "io/memory"

describe TaggedLogger::Logger do
  it "should accept settings" do
    TaggedLogger::Logger.configure do
      settings.log_tags.should eq ([] of Proc(TaggedLogger::Logger, Nil))
    end
    logger = TaggedLogger::Logger.new

    # Should not raise errors
    Habitat.raise_if_missing_settings!
  end

  it "should tag messages sent to the logger" do
    mem = IO::Memory.new
    logger = TaggedLogger::Logger.new(mem)
    logger.tagged("domain") do
      logger.tagged("user") do
        logger.info "testing"
      end
    end

    mem.to_s.split(" : ")[1].should eq "[domain] [user] testing\n"
  end

  it "should support proc tags as settings" do
    mem = IO::Memory.new

    TaggedLogger::Logger.configure do
      settings.log_tags << ->{
        "another"
      }
    end

    logger = TaggedLogger::Logger.new(mem)
    logger.tagged("domain") do
      logger.tagged("user") do
        logger.info "testing"
      end
    end

    mem.to_s.split(" : ")[1].should eq "[another] [domain] [user] testing\n"
  end
end
