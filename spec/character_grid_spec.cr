require "./spec_helper"
require "../src/opal/graphics/grid_style"
require "../src/opal/graphics/primitives_2d"
require "../src/opal/ui/components/character_grid"

describe Opal::Graphics::GridStylePreset do
  it "parses preset strings and symbols correctly" do
    Opal::Graphics::GridStylePreset.parse?(:solid).should eq(Opal::Graphics::GridStylePreset::Solid)
    Opal::Graphics::GridStylePreset.parse?("heavy").should eq(Opal::Graphics::GridStylePreset::Heavy)
    Opal::Graphics::GridStylePreset.parse?("double").should eq(Opal::Graphics::GridStylePreset::Double)
    Opal::Graphics::GridStylePreset.parse?("dashed").should eq(Opal::Graphics::GridStylePreset::Dashed)
    Opal::Graphics::GridStylePreset.parse?("dotted").should eq(Opal::Graphics::GridStylePreset::Dotted)
    Opal::Graphics::GridStylePreset.parse?("dots").should eq(Opal::Graphics::GridStylePreset::Dots)
    Opal::Graphics::GridStylePreset.parse?("crosses").should eq(Opal::Graphics::GridStylePreset::Crosses)
    Opal::Graphics::GridStylePreset.parse?("ascii").should eq(Opal::Graphics::GridStylePreset::Ascii)
    Opal::Graphics::GridStylePreset.parse?("blocks").should eq(Opal::Graphics::GridStylePreset::Blocks)
    Opal::Graphics::GridStylePreset.parse?("math_quad").should eq(Opal::Graphics::GridStylePreset::MathQuad)
    Opal::Graphics::GridStylePreset.parse?("nonexistent").should be_nil
  end

  it "returns appropriate glyphs for all 10 presets" do
    solid = Opal::Graphics::GridGlyphs.preset(:solid)
    solid.horizontal.should eq('─')
    solid.vertical.should eq('│')
    solid.intersection.should eq('┼')

    heavy = Opal::Graphics::GridGlyphs.preset(:heavy)
    heavy.horizontal.should eq('━')
    heavy.vertical.should eq('┃')
    heavy.intersection.should eq('╋')

    double = Opal::Graphics::GridGlyphs.preset(:double)
    double.horizontal.should eq('═')
    double.vertical.should eq('║')
    double.intersection.should eq('╬')

    ascii = Opal::Graphics::GridGlyphs.preset(:ascii)
    ascii.horizontal.should eq('-')
    ascii.vertical.should eq('|')
    ascii.intersection.should eq('+')

    math = Opal::Graphics::GridGlyphs.preset(:math_quad)
    math.horizontal.should eq('─')
    math.vertical.should eq('│')
    math.intersection.should eq('·')
  end
end

describe Opal::Graphics::Primitives2D do
  describe ".draw_grid" do
    it "renders a standard grid on buffer cells" do
      buf = Opal::UI::Buffer.new(5, 5)
      Opal::Graphics::Primitives2D.draw_grid(
        buf,
        x: 0, y: 0, width: 5, height: 5,
        interval_x: 2, interval_y: 2,
        offset_x: 0, offset_y: 0,
        style: :ascii
      )

      # At (0,0), (2,0), (4,0), (0,2), (2,2), (4,2), (0,4), (2,4), (4,4) should be '+'
      buf.get(0, 0).char.should eq('+')
      buf.get(2, 0).char.should eq('+')
      buf.get(4, 0).char.should eq('+')
      buf.get(2, 2).char.should eq('+')

      # At (1, 0), (3, 0) should be horizontal '-'
      buf.get(1, 0).char.should eq('-')
      buf.get(3, 0).char.should eq('-')

      # At (0, 1), (0, 3) should be vertical '|'
      buf.get(0, 1).char.should eq('|')
      buf.get(0, 3).char.should eq('|')

      # At (1, 1), (3, 3) should be empty ' '
      buf.get(1, 1).char.should eq(' ')
      buf.get(3, 3).char.should eq(' ')
    end

    it "respects panning offsets" do
      buf = Opal::UI::Buffer.new(5, 5)
      # Offset by 1 in x and y
      Opal::Graphics::Primitives2D.draw_grid(
        buf,
        x: 0, y: 0, width: 5, height: 5,
        interval_x: 2, interval_y: 2,
        offset_x: 1, offset_y: 1,
        style: :ascii
      )

      # Origin '+' shifted from (0,0) to (1,1)
      buf.get(1, 1).char.should eq('+')
      buf.get(3, 1).char.should eq('+')
      buf.get(1, 3).char.should eq('+')
      buf.get(3, 3).char.should eq('+')
    end
  end
end

describe Opal::UI::CharacterGrid do
  it "initializes with configurable properties" do
    grid = Opal::UI::CharacterGrid.new(
      interval_x: 10,
      interval_y: 5,
      style: :double,
      show_border: false
    )

    grid.interval_x.should eq(10)
    grid.interval_y.should eq(5)
    grid.current_style.should eq(Opal::Graphics::GridStylePreset::Double)
    grid.show_border?.should be_false
  end

  it "pans and cycles styles interactively" do
    grid = Opal::UI::CharacterGrid.new(interval_x: 8, interval_y: 4, style: :solid)
    grid.pan(3, -2)
    grid.offset_x.should eq(3)
    grid.offset_y.should eq(-2)

    s1 = grid.cycle_style
    s1.should eq(Opal::Graphics::GridStylePreset::Heavy)

    grid.reset
    grid.offset_x.should eq(0)
    grid.offset_y.should eq(0)
  end

  it "handles keyboard navigation" do
    grid = Opal::UI::CharacterGrid.new(interval_x: 6, interval_y: 3)

    # Arrow keys
    right_key = Opal::Terminal::KeyEvent.new("right")
    grid.handle_key(right_key).should be_true
    grid.offset_x.should eq(1)

    down_key = Opal::Terminal::KeyEvent.new("down")
    grid.handle_key(down_key).should be_true
    grid.offset_y.should eq(1)

    # Style switch key 's'
    s_key = Opal::Terminal::KeyEvent.new("s", 's')
    grid.handle_key(s_key).should be_true
    grid.current_style.should eq(Opal::Graphics::GridStylePreset::Heavy)

    # Reset key '0'
    zero_key = Opal::Terminal::KeyEvent.new("0", '0')
    grid.handle_key(zero_key).should be_true
    grid.offset_x.should eq(0)
    grid.offset_y.should eq(0)
  end

  it "renders without errors onto a buffer" do
    grid = Opal::UI::CharacterGrid.new(
      interval_x: 4,
      interval_y: 2,
      style: :math_quad,
      show_coordinates: true,
      title: "Test Grid"
    )

    buf = Opal::UI::Buffer.new(30, 12)
    grid.render(buf, 0, 0, 30, 12)
    # Check that something was rendered
    buf.get(0, 0).char.should_not eq('\0')
  end
end
