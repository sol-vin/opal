require "./spec_helper"

describe Opal::ColorSpaces do
  it "converts sRGB to CIE XYZ and back" do
    # Pure red
    x, y, z = Opal::ColorSpaces.rgb_to_xyz(255, 0, 0)
    x.should be_close(0.4124, 0.01)
    y.should be_close(0.2126, 0.01)
    z.should be_close(0.0193, 0.01)

    r, g, b = Opal::ColorSpaces.xyz_to_rgb(x, y, z)
    r.should eq(255_u8)
    g.should eq(0_u8)
    b.should eq(0_u8)
  end

  it "converts sRGB to CIELAB and back" do
    # White
    l, a, b_val = Opal::ColorSpaces.rgb_to_lab(255, 255, 255)
    l.should be_close(100.0, 0.5)
    a.should be_close(0.0, 0.5)
    b_val.should be_close(0.0, 0.5)

    r, g, b = Opal::ColorSpaces.lab_to_rgb(100.0, 0.0, 0.0)
    r.should eq(255_u8)
    g.should eq(255_u8)
    b.should eq(255_u8)

    # Black
    l, a, b_val = Opal::ColorSpaces.rgb_to_lab(0, 0, 0)
    l.should be_close(0.0, 0.1)

    r, g, b = Opal::ColorSpaces.lab_to_rgb(0.0, 0.0, 0.0)
    r.should eq(0_u8)
    g.should eq(0_u8)
    b.should eq(0_u8)
  end

  it "converts sRGB to Oklab and back" do
    l, a, b_val = Opal::ColorSpaces.rgb_to_oklab(255, 0, 0) # Red
    l.should be_close(0.627, 0.02)
    a.should be_close(0.224, 0.02)
    b_val.should be_close(0.126, 0.02)

    r, g, b = Opal::ColorSpaces.oklab_to_rgb(l, a, b_val)
    r.should eq(255_u8)
    g.should eq(0_u8)
    b.should eq(0_u8)
  end

  it "converts sRGB to Oklch and back" do
    l, c, h = Opal::ColorSpaces.rgb_to_oklch(0, 255, 0) # Green
    l.should be > 0.5
    c.should be > 0.2
    (h >= 0.0 && h <= 360.0).should be_true

    r, g, b = Opal::ColorSpaces.oklch_to_rgb(l, c, h)
    r.should eq(0_u8)
    g.should eq(255_u8)
    b.should eq(0_u8)
  end

  it "converts sRGB to CMYK and back" do
    c, m, y, k = Opal::ColorSpaces.rgb_to_cmyk(0, 255, 255) # Cyan
    c.should be_close(1.0, 0.01)
    m.should be_close(0.0, 0.01)
    y.should be_close(0.0, 0.01)
    k.should be_close(0.0, 0.01)

    r, g, b = Opal::ColorSpaces.cmyk_to_rgb(1.0, 0.0, 0.0, 0.0)
    r.should eq(0_u8)
    g.should eq(255_u8)
    b.should eq(255_u8)
  end

  it "converts sRGB to HSL and back" do
    h, s, l = Opal::ColorSpaces.rgb_to_hsl(255, 128, 0)
    h.should be_close(30.0, 1.0)
    s.should be_close(1.0, 0.01)
    l.should be_close(0.5, 0.01)

    r, g, b = Opal::ColorSpaces.hsl_to_rgb(30.0, 1.0, 0.5)
    r.should eq(255_u8)
    g.should eq(128_u8)
    b.should eq(0_u8)
  end

  it "provides extension methods on Opal::Color" do
    col = Opal::Color.rgb(100, 150, 200)

    lab = col.to_lab
    lab[0].should be > 0.0

    xyz = col.to_xyz
    xyz[0].should be > 0.0

    oklab = col.to_oklab
    oklab[0].should be > 0.0

    oklch = col.to_oklch
    oklch[0].should be > 0.0

    cmyk = col.to_cmyk
    cmyk[3].should be > 0.0

    hsl = col.to_hsl
    hsl[0].should be > 0.0

    hsv = col.to_hsv
    hsv[2].should be > 0.0

    # Constructors
    Opal::Color.lab(lab[0], lab[1], lab[2]).to_rgb.should eq(col.to_rgb)
    Opal::Color.xyz(xyz[0], xyz[1], xyz[2]).to_rgb.should eq(col.to_rgb)
    Opal::Color.oklab(oklab[0], oklab[1], oklab[2]).to_rgb.should eq(col.to_rgb)
    Opal::Color.cmyk(cmyk[0], cmyk[1], cmyk[2], cmyk[3]).to_rgb.should eq(col.to_rgb)
    Opal::Color.hsl(hsl[0], hsl[1], hsl[2]).to_rgb.should eq(col.to_rgb)
  end
end
