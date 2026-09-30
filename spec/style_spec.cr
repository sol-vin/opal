require "./spec_helper"

describe Opal::Color do
  it "generates ANSI 16 color escapes" do
    red = Opal::Color.red
    red.type.should eq(Opal::Color::Type::ANSI16)
    red.fg_escape.should eq("\e[31m")
    red.bg_escape.should eq("\e[41m")

    cyan = Opal::Color.cyan
    cyan.fg_escape.should eq("\e[36m")
    cyan.bg_escape.should eq("\e[46m")
  end

  it "generates ANSI 256 color escapes" do
    c = Opal::Color.index(123)
    c.type.should eq(Opal::Color::Type::ANSI256)
    c.fg_escape.should eq("\e[38;5;123m")
    c.bg_escape.should eq("\e[48;5;123m")
  end

  it "generates 24-bit TrueColor RGB escapes" do
    c = Opal::Color.rgb(100, 150, 200)
    c.type.should eq(Opal::Color::Type::RGB)
    c.fg_escape.should eq("\e[38;2;100;150;200m")
    c.bg_escape.should eq("\e[48;2;100;150;200m")
  end

  it "parses hex color codes" do
    c1 = Opal::Color.hex("#ff79c6")
    c1.r.should eq(255)
    c1.g.should eq(121)
    c1.b.should eq(198)

    c2 = Opal::Color.hex("61AFEF")
    c2.r.should eq(97)
    c2.g.should eq(175)
    c2.b.should eq(239)

    c3 = Opal::Color.hex("#fff")
    c3.r.should eq(255)
    c3.g.should eq(255)
    c3.b.should eq(255)
  end

  it "resolves colors using Color.from" do
    Opal::Color.from(:red).fg_escape.should eq("\e[31m")
    Opal::Color.from("yellow").fg_escape.should eq("\e[33m")
    Opal::Color.from("#00ff00").fg_escape.should eq("\e[38;2;0;255;0m")
  end
end

describe Opal::VisualWidth do
  it "computes width of plain ASCII text" do
    Opal::VisualWidth.width("Hello World").should eq(11)
  end

  it "ignores ANSI escape sequences when computing width" do
    styled = "\e[31;1mHello\e[0m \e[34mWorld\e[0m"
    Opal::VisualWidth.width(styled).should eq(11)
    Opal::VisualWidth.strip_ansi(styled).should eq("Hello World")
  end

  it "measures East Asian wide characters as 2 columns" do
    Opal::VisualWidth.width("你好世界").should eq(8)
    Opal::VisualWidth.width("Crystal言語").should eq(11)
  end

  it "measures emojis as 2 columns" do
    Opal::VisualWidth.width("🎮 Rocket").should eq(9)
    Opal::VisualWidth.char_width('⚡').should eq(2)        # U+26A1 High Voltage
    Opal::VisualWidth.char_width('✨').should eq(2)        # U+2728 Sparkles
    Opal::VisualWidth.char_width('☕').should eq(2)        # U+2615 Hot Beverage
    Opal::VisualWidth.char_width('\u{26A0}').should eq(2) # U+26A0 Warning
    Opal::VisualWidth.char_width('🍵').should eq(2)        # U+1F375 Teacup
    Opal::VisualWidth.char_width('💎').should eq(2)        # U+1F48E Gem
    Opal::VisualWidth.char_width('✔').should eq(1)        # U+2714 Checkmark (text presentation)
  end

  it "truncates text with ellipsis" do
    Opal::VisualWidth.truncate("Hello World", 8).should eq("Hello...")
    Opal::VisualWidth.truncate("Short", 10).should eq("Short")
  end
end

describe Opal::Style do
  it "chains fluent modifiers" do
    style = Opal::Style.new
      .bold
      .italic
      .underline
      .fg(:cyan)
      .bg(:black)

    style.bold?.should be_true
    style.italic?.should be_true
    style.underline?.should be_true
    style.foreground.fg_escape.should eq("\e[36m")
    style.background.bg_escape.should eq("\e[40m")
  end

  it "applies text decorations in rendered output" do
    rendered = Opal::Style.new.bold.fg(:red).render("Error!")
    rendered.should contain("\e[1m")
    rendered.should contain("\e[31m")
    rendered.should contain("Error!")
    rendered.should end_with("\e[0m")
  end

  it "pads text horizontally and vertically" do
    style = Opal::Style.new.padding(1, 2)
    rendered = style.render("Box")
    lines = rendered.split('\n')
    lines.size.should eq(3) # 1 top blank line + 1 content line + 1 bottom blank line
    lines[1].should eq("  Box  ")
  end

  it "renders borders around content" do
    style = Opal::Style.new.border(:rounded).padding(0, 1)
    rendered = style.render("Lapis")
    lines = rendered.split('\n')
    lines.size.should eq(3)
    lines[0].should eq("╭───────╮")
    lines[1].should eq("│ Lapis │")
    lines[2].should eq("╰───────╯")
  end

  it "aligns text inside fixed width" do
    left = Opal::Style.new.width(10).align(:left).render("Hi")
    left.should eq("Hi        ")

    center = Opal::Style.new.width(10).align(:center).render("Hi")
    center.should eq("    Hi    ")

    right = Opal::Style.new.width(10).align(:right).render("Hi")
    right.should eq("        Hi")
  end
end

describe Opal::Layout do
  it "joins multi-line blocks horizontally" do
    block_a = "A1\nA2"
    block_b = "B1\nB2"
    joined = Opal::Layout.join_horizontal(:top, block_a, block_b, spacing: 2)
    joined.should eq("A1  B1\nA2  B2")
  end

  it "joins multi-line blocks horizontally with different heights" do
    block_a = "A1\nA2\nA3"
    block_b = "B1"
    joined = Opal::Layout.join_horizontal(:top, block_a, block_b, spacing: 1)
    lines = joined.split('\n')
    lines.size.should eq(3)
    lines[0].should eq("A1 B1")
    lines[1].should eq("A2   ")
    lines[2].should eq("A3   ")
  end

  it "stacks blocks vertically" do
    block_a = "Top"
    block_b = "Bottom"
    stacked = Opal::Layout.join_vertical(:left, block_a, block_b, spacing: 1)
    stacked.should eq("Top\n\nBottom")
  end
end
