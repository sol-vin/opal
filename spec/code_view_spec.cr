require "./spec_helper"

describe "Opal::UI::CodeView" do
  it "initializes with code, language, and line numbers" do
    sample_code = <<-CR
    def hello(name : String) : String
      "Hello, \#{name}!"
    end
    CR

    cv = Opal::UI::CodeView.new(sample_code, language: :crystal, show_line_numbers: true)
    cv.lines.size.should eq(3)
    cv.show_line_numbers?.should be_true
    cv.scroll_offset.should eq(0)
  end

  it "renders into buffer with gutter and syntax formatting" do
    sample = "let x = 42;\nconsole.log(x);"
    cv = Opal::UI::CodeView.new(sample, language: :javascript, show_line_numbers: true)
    buf = Opal::UI::Buffer.new(40, 5)
    cv.render(buf, 0, 0, 40, 5)
    output = buf.to_s
    output.should contain("let")
    output.should contain("42")
  end

  it "supports scrollable toggling and auto-scroll animation" do
    lines = (1..30).map { |i| "row_#{i} = #{i} * 2" }.join("\n")
    cv = Opal::UI::CodeView.new(lines, language: :python, auto_scroll: true, scroll_speed: 3.0)

    # Initial scroll offset
    cv.scroll_offset.should eq(0)

    # Ticking should increment scroll
    cv.tick(1.0)
    cv.scroll_offset.should be > 0

    # Disabling scrollable prevents scrolling
    cv.scrollable = false
    curr = cv.scroll_offset
    cv.scroll_down(4)
    cv.scroll_offset.should eq(curr)
  end
end
