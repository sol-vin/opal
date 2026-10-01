require "./spec_helper"

describe "Opal::UI::MaskMap & Alpha Masking" do
  it "initializes, gets, and sets weights clamped to 0.0..1.0" do
    mask = Opal::UI::MaskMap.new(10, 10, 0.0)
    mask.set(3, 3, 0.75)
    mask.get(3, 3).should eq(0.75)

    mask.set(2, 2, 2.5) # Clamps to 1.0
    mask.get(2, 2).should eq(1.0)

    mask.set(1, 1, -0.5) # Clamps to 0.0
    mask.get(1, 1).should eq(0.0)

    # Out of bounds returns 0.0
    mask.get(-1, 0).should eq(0.0)
    mask.get(100, 100).should eq(0.0)
  end

  it "inverts mask weights" do
    mask = Opal::UI::MaskMap.new(4, 4, 0.2)
    inverted = mask.invert
    inverted.get(0, 0).should be_close(0.8, 0.001)
  end

  it "generates radial spotlight mask with aspect ratio compensation" do
    # Center at (10, 5), radius: 4.0
    mask = Opal::UI::MaskMap.radial(cx: 10, cy: 5, radius: 4.0, feather: 2.0, width: 20, height: 10)
    # Center must be 1.0 (inside inner radius)
    mask.get(10, 5).should eq(1.0)

    # Far away must be 0.0
    mask.get(0, 0).should eq(0.0)
    mask.get(19, 9).should eq(0.0)

    # In feather zone, should be between 0.0 and 1.0
    weight = mask.get(13, 5)
    (weight > 0.0 && weight < 1.0).should be_true
  end

  it "maps weights to Unicode shade characters" do
    Opal::UI::MaskMap.dither_char(0.0).should eq(' ')
    Opal::UI::MaskMap.dither_char(0.25).should eq('░')
    Opal::UI::MaskMap.dither_char(0.50).should eq('▒')
    Opal::UI::MaskMap.dither_char(0.75).should eq('▓')
    Opal::UI::MaskMap.dither_char(1.0).should eq('█')
  end

  it "masks buffer writes strictly to mask map weights" do
    buf = Opal::UI::Buffer.new(10, 5)
    mask = Opal::UI::MaskMap.new(10, 5, 0.0)
    # Allow only coordinate (3, 2)
    mask.set(3, 2, 1.0)

    buf.with_mask(mask) do
      buf.fill(0, 0, 10, 5, Opal::UI::Cell.new(char: 'Z'))
    end

    buf.get(3, 2).char.should eq('Z')
    buf.get(0, 0).char.should eq(' ')
    buf.get(4, 2).char.should eq(' ')
  end

  it "applies feathered dithering to space characters in feather zone" do
    buf = Opal::UI::Buffer.new(5, 5)
    mask = Opal::UI::MaskMap.new(5, 5, 0.5)

    buf.with_mask(mask, feather: true) do
      buf.put_char(2, 2, ' ')
    end

    # Space cell with 0.5 weight should be dithered with '▒'
    buf.get(2, 2).char.should eq('▒')
  end
end
