require "./spec_helper"
require "../src/opal/ui/components/palette"

describe Opal::UI::Palette do
  it "initializes indexed and named palettes via constructors" do
    indexed = Opal::UI::Palette.indexed([Opal::Color.hex("#FF0000"), Opal::Color.hex("#00FF00")])
    indexed.model.mode.should eq(Opal::PaletteMode::Indexed)
    indexed.model.size.should eq(2)

    named = Opal::UI::Palette.named({"primary" => Opal::Color.hex("#38EF7D")})
    named.model.mode.should eq(Opal::PaletteMode::Named)
    named.model.size.should eq(1)
  end

  it "navigates cursor and swaps colors with [ and ] without collision" do
    colors = [Opal::Color.hex("#111111"), Opal::Color.hex("#222222"), Opal::Color.hex("#333333")]
    palette = Opal::UI::Palette.indexed(colors)

    # Initial cursor at 0
    palette.cursor.should eq(0)

    # Move right
    r_key = Opal::Terminal::KeyEvent.new("right")
    palette.handle_key(r_key).should be_true
    palette.cursor.should eq(1)

    # Swap left using '['
    swap_left_key = Opal::Terminal::KeyEvent.new("[", '[')
    palette.handle_key(swap_left_key).should be_true
    palette.cursor.should eq(0)
    palette.model.color_at(0).not_nil!.to_hex.should eq("#222222")
    palette.model.color_at(1).not_nil!.to_hex.should eq("#111111")

    # Swap right using ']'
    swap_right_key = Opal::Terminal::KeyEvent.new("]", ']')
    palette.handle_key(swap_right_key).should be_true
    palette.cursor.should eq(1)
    palette.model.color_at(0).not_nil!.to_hex.should eq("#111111")
    palette.model.color_at(1).not_nil!.to_hex.should eq("#222222")
  end

  it "opens ColorPicker, updates active color, and confirms" do
    colors = [Opal::Color.hex("#FF0000"), Opal::Color.hex("#00FF00")]
    palette = Opal::UI::Palette.indexed(colors)

    enter_key = Opal::Terminal::KeyEvent.new("enter")
    palette.handle_key(enter_key).should be_true
    palette.editing_color?.should be_true

    # ColorPicker now receives events; simulate confirming a new color
    palette.confirm_color_edit(Opal::Color.hex("#0000FF"))
    palette.editing_color?.should be_false
    palette.model.color_at(0).not_nil!.to_hex.should eq("#0000FF")
  end

  it "supports inline renaming in named mode" do
    entries = {"bg" => Opal::Color.hex("#111111")}
    palette = Opal::UI::Palette.named(entries)

    r_key = Opal::Terminal::KeyEvent.new("r", 'r')
    palette.handle_key(r_key).should be_true
    palette.renaming?.should be_true
    palette.rename_buffer.should eq("bg")

    # Type '2'
    char_key = Opal::Terminal::KeyEvent.new("2", '2')
    palette.handle_key(char_key).should be_true
    palette.rename_buffer.should eq("bg2")

    # Enter confirms
    enter_key = Opal::Terminal::KeyEvent.new("enter")
    palette.handle_key(enter_key).should be_true
    palette.renaming?.should be_false
    palette.model.name_at(0).should eq("bg2")
  end

  it "renders both indexed and named modes to a buffer without error" do
    buf = Opal::UI::Buffer.new(60, 20)

    indexed = Opal::UI::Palette.indexed([Opal::Color.hex("#AA0000"), Opal::Color.hex("#00AA00")])
    indexed.render(buf, 0, 0, 60, 20)
    buf.get(0, 0).char.should_not eq('\0')

    named = Opal::UI::Palette.named({"test" => Opal::Color.hex("#123456")})
    named.render(buf, 0, 0, 60, 20)
    buf.get(0, 0).char.should_not eq('\0')
  end
end
