require "./spec_helper"

describe Opal::Image::PixelBuffer do
  it "creates an empty buffer and accesses pixels" do
    buf = Opal::Image::PixelBuffer.new(10, 8, Opal::Color.black)
    buf.width.should eq(10)
    buf.height.should eq(8)
    buf.get(0, 0).should eq(Opal::Color.black)

    buf.set(5, 4, Opal::Color.rgb(255, 128, 64))
    buf.get(5, 4).should eq(Opal::Color.rgb(255, 128, 64))
    buf.get(15, 20).should eq(Opal::Color.none)
  end

  it "resizes using nearest-neighbor interpolation" do
    buf = Opal::Image::PixelBuffer.new(2, 2)
    buf.set(0, 0, Opal::Color.rgb(255, 0, 0))
    buf.set(1, 0, Opal::Color.rgb(0, 255, 0))
    buf.set(0, 1, Opal::Color.rgb(0, 0, 255))
    buf.set(1, 1, Opal::Color.rgb(255, 255, 255))

    scaled = buf.resize(4, 4, Opal::Image::Interpolation::Nearest)
    scaled.width.should eq(4)
    scaled.height.should eq(4)
    scaled.get(0, 0).should eq(Opal::Color.rgb(255, 0, 0))
    scaled.get(3, 3).should eq(Opal::Color.rgb(255, 255, 255))
  end

  it "resizes using bilinear interpolation blending RGB channels smoothly" do
    buf = Opal::Image::PixelBuffer.new(2, 2)
    buf.set(0, 0, Opal::Color.rgb(0, 0, 0))
    buf.set(1, 0, Opal::Color.rgb(200, 0, 0))
    buf.set(0, 1, Opal::Color.rgb(0, 0, 0))
    buf.set(1, 1, Opal::Color.rgb(200, 0, 0))

    scaled = buf.resize(3, 2, Opal::Image::Interpolation::Bilinear)
    scaled.width.should eq(3)
    scaled.height.should eq(2)
    # The middle pixel should be interpolated between 0 and 200
    mid_color = scaled.get(1, 0)
    mid_color.r.should be > 50_u8
    mid_color.r.should be < 150_u8
  end

  it "generates procedural sample images" do
    gem = Opal::Image::PixelBuffer.sample_gem(20, 20)
    gem.width.should eq(20)
    gem.height.should eq(20)
    center = gem.get(10, 10)
    center.type.should eq(Opal::Color::Type::RGB)

    landscape = Opal::Image::PixelBuffer.sample_landscape(24, 18)
    landscape.width.should eq(24)
    landscape.height.should eq(18)
  end

  it "parses PPM ASCII P3 image" do
    ppm = <<-PPM
    P3
    2 2
    255
    255 0 0
    0 255 0
    0 0 255
    255 255 255
    PPM

    buf = Opal::Image::PixelBuffer.from_ppm(ppm)
    buf.width.should eq(2)
    buf.height.should eq(2)
    buf.get(0, 0).should eq(Opal::Color.rgb(255, 0, 0))
    buf.get(1, 0).should eq(Opal::Color.rgb(0, 255, 0))
    buf.get(0, 1).should eq(Opal::Color.rgb(0, 0, 255))
    buf.get(1, 1).should eq(Opal::Color.rgb(255, 255, 255))
  end
end

describe Opal::UI::AsciiImage do
  it "renders in HalfBlock mode using Unicode '▀' and dual pixel colors" do
    img = Opal::Image::PixelBuffer.new(4, 4)
    img.set(0, 0, Opal::Color.rgb(255, 0, 0))
    img.set(0, 1, Opal::Color.rgb(0, 0, 255))

    ascii = Opal::UI::AsciiImage.new(img, mode: :half_block)
    buf = Opal::UI::Buffer.new(4, 2)
    ascii.render(buf, 0, 0, 4, 2)

    cell = buf.get(0, 0)
    cell.char.should eq('▀')
    cell.fg.should eq(Opal::Color.rgb(255, 0, 0))
    cell.bg.should eq(Opal::Color.rgb(0, 0, 255))
  end

  it "renders in NearestChar mode mapping luminance to ASCII density" do
    img = Opal::Image::PixelBuffer.new(4, 2)
    img.set(0, 0, Opal::Color.rgb(0, 0, 0))       # Dark -> ' '
    img.set(1, 0, Opal::Color.rgb(255, 255, 255)) # Bright -> '@'

    ascii = Opal::UI::AsciiImage.new(img, mode: :nearest_char, ramp: " .:-=+*#%@")
    buf = Opal::UI::Buffer.new(4, 2)
    ascii.render(buf, 0, 0, 4, 2)

    buf.get(0, 0).char.should eq(' ')
    buf.get(1, 0).char.should eq('@')
  end
end
