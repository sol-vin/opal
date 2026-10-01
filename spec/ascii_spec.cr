require "./spec_helper"

describe Opal::AsciiCode do
  it "maps standard ASCII control characters correctly" do
    Opal::Ascii::Nul.to_i.should eq(0)
    Opal::Ascii::Bell.to_i.should eq(7)
    Opal::Ascii::Backspace.to_i.should eq(8)
    Opal::Ascii::Tab.to_i.should eq(9)
    Opal::Ascii::LineFeed.to_i.should eq(10)
    Opal::Ascii::CarriageReturn.to_i.should eq(13)
    Opal::Ascii::Escape.to_i.should eq(27)
    Opal::Ascii::Delete.to_i.should eq(127)
  end

  it "renders standard printable characters" do
    Opal::Ascii::Space.char.should eq(' ')
    Opal::Ascii::Hash.char.should eq('#')
    Opal::Ascii::Asterisk.char.should eq('*')
    Opal::Ascii::Plus.char.should eq('+')
    Opal::Ascii::Hyphen.char.should eq('-')
    Opal::Ascii::Pipe.char.should eq('|')
    Opal::Ascii::BracketOpen.char.should eq('[')
    Opal::Ascii::BracketClose.char.should eq(']')
  end

  it "maps Code Page 437 terminal UI pieces and their fallbacks" do
    Opal::Ascii::ArrowRight.char.should eq('→')
    Opal::Ascii::ArrowRight.ascii_fallback.should eq('>')

    Opal::Ascii::ArrowLeft.char.should eq('←')
    Opal::Ascii::ArrowLeft.ascii_fallback.should eq('<')

    Opal::Ascii::BoxHorizontal.char.should eq('─')
    Opal::Ascii::BoxHorizontal.ascii_fallback.should eq('-')

    Opal::Ascii::BoxVertical.char.should eq('│')
    Opal::Ascii::BoxVertical.ascii_fallback.should eq('|')

    Opal::Ascii::BoxCross.char.should eq('┼')
    Opal::Ascii::BoxCross.ascii_fallback.should eq('+')

    Opal::Ascii::BoxFullBlock.char.should eq('█')
    Opal::Ascii::BoxFullBlock.ascii_fallback.should eq('#')

    Opal::Ascii::TriangleUp.char.should eq('▲')
    Opal::Ascii::TriangleUp.ascii_fallback.should eq('^')

    Opal::Ascii::TriangleDown.char.should eq('▼')
    Opal::Ascii::TriangleDown.ascii_fallback.should eq('v')
  end

  it "finds code entries by case-insensitive name" do
    Opal::AsciiCode.find?("box_horizontal").should eq(Opal::Ascii::BoxHorizontal)
    Opal::AsciiCode.find?("arrow-right").should eq(Opal::Ascii::ArrowRight)
    Opal::AsciiCode.find?("escape").should eq(Opal::Ascii::Escape)
    Opal::AsciiCode.find?("nonexistent").should be_nil
  end

  it "resolves code from character" do
    Opal::AsciiCode.from_char?('─').should eq(Opal::Ascii::BoxHorizontal)
    Opal::AsciiCode.from_char?('│').should eq(Opal::Ascii::BoxVertical)
  end
end
