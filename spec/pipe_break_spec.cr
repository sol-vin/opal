require "./spec_helper"
require "../src/opal/terminal/posix"
require "../src/opal/terminal/windows"

class BrokenPipeIO < IO
  def read(slice : Bytes) : Int32
    raise IO::Error.new("Broken pipe (EPIPE)")
  end

  def write(slice : Bytes) : Nil
    raise IO::Error.new("Broken pipe (EPIPE)")
  end

  def flush : Nil
    raise IO::Error.new("Broken pipe (EPIPE)")
  end
end

describe "Crash & Pipe Break Protection" do
  it "PosixDriver safely catches IO::Error without crashing" do
    broken_io = BrokenPipeIO.new
    driver = Opal::Terminal::PosixDriver.new(input: broken_io, output: broken_io)

    # Neither write nor flush should raise unhandled exceptions
    expect_raises(Exception) do
      # Should NOT raise, so this block will fail expect_raises if no exception
      driver.write("hello")
      driver.flush
      raise RuntimeError.new("no_crash")
    end.message.should eq("no_crash")
  end

  it "WindowsDriver safely catches IO::Error without crashing" do
    broken_io = BrokenPipeIO.new
    driver = Opal::Terminal::WindowsDriver.new(input: broken_io, output: broken_io)

    # Neither write nor flush should raise unhandled exceptions
    expect_raises(Exception) do
      driver.write("hello")
      driver.flush
      raise RuntimeError.new("no_crash")
    end.message.should eq("no_crash")
  end
end
