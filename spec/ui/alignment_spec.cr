require "../spec_helper"

describe "Alignment and Visual Width Resilience" do
  describe "Opal::VisualWidth" do
    it "measures ASCII strings accurately" do
      Opal::VisualWidth.width("Hello").should eq(5)
      Opal::VisualWidth.width("").should eq(0)
      Opal::VisualWidth.width("1234567890").should eq(10)
    end

    it "measures wide CJK characters as 2 columns" do
      Opal::VisualWidth.width("こんにちは").should eq(10) # 5 chars * 2 = 10
      Opal::VisualWidth.width("你好世界").should eq(8)   # 4 chars * 2 = 8
      Opal::VisualWidth.width("한글").should eq(4)     # 2 chars * 2 = 4
    end

    it "measures emojis as 2 columns" do
      Opal::VisualWidth.width("🚀").should eq(2)
      Opal::VisualWidth.width("🔥").should eq(2)
      Opal::VisualWidth.width("⚡").should eq(2)
      Opal::VisualWidth.width("🎉").should eq(2)
    end

    it "ignores ANSI escape sequences in width calculation" do
      colored = "\e[31mHello\e[0m"
      Opal::VisualWidth.width(colored).should eq(5)
      bold_cyan = "\e[1;36mWorld\e[0m"
      Opal::VisualWidth.width(bold_cyan).should eq(5)
    end

    it "truncates wide characters without breaking glyphs" do
      truncated = Opal::VisualWidth.truncate("こんにちは世界", 8, "...")
      Opal::VisualWidth.width(truncated).should be <= 8
      truncated.should end_with("...")
    end
  end

  describe "Opal::Style alignment" do
    it "aligns text :left, :center, and :right" do
      style_left = Opal::Style.new.width(10).align(:left)
      style_center = Opal::Style.new.width(10).align(:center)
      style_right = Opal::Style.new.width(10).align(:right)

      left_out = style_left.render("Hi")
      center_out = style_center.render("Hi")
      right_out = style_right.render("Hi")

      Opal::VisualWidth.strip_ansi(left_out).should start_with("Hi")
      Opal::VisualWidth.strip_ansi(right_out).should end_with("Hi")
      Opal::VisualWidth.strip_ansi(center_out).strip.should eq("Hi")
    end

    it "correctly aligns wide Unicode strings" do
      style_center = Opal::Style.new.width(14).align(:center)
      rendered = style_center.render("日本語") # 6 columns
      plain = Opal::VisualWidth.strip_ansi(rendered)
      plain.size.should be >= 7 # Padded with spaces
      plain.should contain("日本語")
    end
  end

  describe "Opal::Layout alignment" do
    it "joins lines vertically with :left, :center, :right alignment" do
      blocks = ["Short", "A Much Longer Line"]

      left = Opal::Layout.join_vertical(:left, blocks)
      center = Opal::Layout.join_vertical(:center, blocks)
      right = Opal::Layout.join_vertical(:right, blocks)

      left.lines[0].should start_with("Short")
      right.lines[0].should end_with("Short")
      center.lines[0].strip.should eq("Short")
    end

    it "joins blocks horizontally with :top, :center, :bottom alignment" do
      b1 = "Line1\nLine2\nLine3"
      b2 = "Single"

      top = Opal::Layout.join_horizontal(:top, [b1, b2], spacing: 2)
      top.lines[0].should contain("Line1  Single")

      bottom = Opal::Layout.join_horizontal(:bottom, [b1, b2], spacing: 2)
      bottom.lines[2].should contain("Line3  Single")
    end
  end

  describe "Opal::UI::Rule alignment" do
    it "renders horizontal rules with :left, :center, and :right aligned text" do
      rule_c = Opal::UI::Rule.to_string(text: "INFO", width: 20, align: :center, color: false)
      rule_l = Opal::UI::Rule.to_string(text: "LEFT", width: 20, align: :left, color: false)
      rule_r = Opal::UI::Rule.to_string(text: "RIGHT", width: 20, align: :right, color: false)

      rule_c.should contain(" INFO ")
      rule_l.should start_with("─ LEFT ")
      rule_r.strip.should end_with(" RIGHT ─")
    end
  end
end
