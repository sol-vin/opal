require "./spec_helper"
require "../src/opal/clipboard"

describe Opal::Clipboard do
  it "generates and writes OSC 52 sequence to IO" do
    io = IO::Memory.new
    success = Opal::Clipboard.copy("Hello Opal Clipboard", io: io, use_native: false, use_osc52: true)
    success.should be_true

    output = io.to_s
    output.should contain("\e]52;c;")
    output.should end_with("\e\\")

    # Base64 of "Hello Opal Clipboard"
    expected_b64 = Base64.strict_encode("Hello Opal Clipboard")
    output.should contain(expected_b64)
  end

  it "reports supported? as true" do
    Opal::Clipboard.supported?.should be_true
  end

  it "executes copy without raising errors" do
    io = IO::Memory.new
    # Should safely return a boolean whether on CI, remote or local desktop
    result = Opal::Clipboard.copy("Safe test string", io: io)
    result.should be_a(Bool)
  end

  it "delegates Opal.copy_to_clipboard directly" do
    io = IO::Memory.new
    Opal.copy_to_clipboard("Delegated", io: io).should be_true
    io.to_s.should contain(Base64.strict_encode("Delegated"))
  end
end
