require "./spec_helper"

describe "Opal::Glyphs & Chars Store" do
  it "provides short constants for shading blocks" do
    Opal::Glyphs::Light.should eq('░')
    Opal::Glyphs::Medium.should eq('▒')
    Opal::Glyphs::Dark.should eq('▓')
    Opal::Glyphs::Full.should eq('█')
    Opal::Chars::Medium.should eq('▒')
  end

  it "provides 1/8th fractional horizontal and vertical block bars" do
    Opal::Glyphs::Bar1.should eq('▏')
    Opal::Glyphs::Bar4.should eq('▌')
    Opal::Glyphs::Bar8.should eq('█')

    Opal::Glyphs::VBar1.should eq(' ')
    Opal::Glyphs::VBar4.should eq('▄')
    Opal::Glyphs::VBar8.should eq('█')
  end

  it "interpolates shades and block gradients smoothly" do
    Opal::Glyphs.shade(0.0).should eq(' ')
    Opal::Glyphs.shade(0.25).should eq('░')
    Opal::Glyphs.shade(0.5).should eq('▒')
    Opal::Glyphs.shade(0.75).should eq('▓')
    Opal::Glyphs.shade(1.0).should eq('█')

    Opal::Glyphs.h_bar(0.5).should eq('▌')
    Opal::Glyphs.v_bar(0.5).should eq('▄')
  end

  it "provides directional pointers, arrows, and spinners" do
    Opal::Glyphs.arrow(:up).should eq('↑')
    Opal::Glyphs.arrow(:down).should eq('↓')
    Opal::Glyphs.arrow(:left).should eq('←')
    Opal::Glyphs.arrow(:right).should eq('→')
    Opal::Glyphs.arrow(:up_right).should eq('↗')

    Opal::Glyphs.triangle(:up).should eq('▲')
    Opal::Glyphs.triangle(:down, small: true).should eq('▾')

    # Spinners
    Opal::Glyphs.spinner_frame(:half_circle, 0).should eq("◐")
    Opal::Glyphs.spinner_frame(:half_circle, 1).should eq("◓")
    Opal::Glyphs.spinner_frame(:half_circle, 2).should eq("◑")
    Opal::Glyphs.spinner_frame(:half_circle, 3).should eq("◒")

    Opal::Glyphs.spinner_frame(:pipe, 0).should eq("|")
    Opal::Glyphs.spinner_frame(:pipe, 1).should eq("/")
  end
end
