require "./spec_helper"
require "../src/opal/image/protocols"

describe "Opal::Image::Protocols" do
  it "detects terminal protocol cleanly" do
    proto = Opal::Image::ProtocolDetector.detect
    [Opal::Image::Protocol::Kitty, Opal::Image::Protocol::ITerm2, Opal::Image::Protocol::Sixel, Opal::Image::Protocol::HalfBlock].includes?(proto).should be_true
  end

  it "encodes raw RGB bytes to Kitty graphics escape sequence" do
    bytes = Bytes.new(3, 255_u8) # 1 white pixel
    encoded = Opal::Image::Encoder.encode_kitty(bytes, 1, 1)
    encoded.should start_with("\e_G")
    encoded.should end_with("\e\\")
    encoded.includes?("f=24").should be_true
  end

  it "encodes iTerm2 inline image sequence" do
    bytes = "test-image".to_slice
    encoded = Opal::Image::Encoder.encode_iterm2(bytes, "test.png")
    encoded.should start_with("\e]1337;File=")
    encoded.should end_with("\a")
  end

  it "renders ImageView component and integrates with DSL" do
    builder = Opal::UI::Builder.new
    img = builder.image_view("assets/logo.png")
    buf = Opal::UI::Buffer.new(40, 10)
    img.render(buf, 0, 0, 40, 10)

    # Check that logo badge title is drawn
    found = (0...10).any? do |y|
      (0...40).any? { |x| buf.get(x, y).char == 'I' && buf.get(x + 1, y).char == 'M' && buf.get(x + 2, y).char == 'G' }
    end
    found.should be_true
  end
end
