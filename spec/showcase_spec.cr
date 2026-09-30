require "./spec_helper"
require "../examples/10_opal_tui_showcase"

describe ShowcaseAppModel do
  it "initializes with 23 slides" do
    app = ShowcaseAppModel.new
    app.slides.size.should eq(23)
    app.current_idx.should eq(0)
  end

  it "renders every single slide without error" do
    app = ShowcaseAppModel.new
    buf = Opal::UI::Buffer.new(80, 24)

    app.slides.each_with_index do |slide, idx|
      buf.clear
      slide.render(buf, 0, 2, 80, 20)
      rendered = buf.render_to_string(with_ansi: false)
      rendered.should_not be_empty
    end
  end

  it "advances linearly through all slides via ESC key" do
    app = ShowcaseAppModel.new
    esc_msg = Opal::TEA::KeyMsg.new("escape")

    23.times do |step|
      app.current_idx.should eq(step)
      app.update(esc_msg)
    end

    # Wraps around to 0
    app.current_idx.should eq(0)
  end

  it "supports backward navigation via p or pageup" do
    app = ShowcaseAppModel.new
    app.update(Opal::TEA::KeyMsg.new("escape"))
    app.current_idx.should eq(1)

    app.update(Opal::TEA::KeyMsg.new("p"))
    app.current_idx.should eq(0)
  end

  it "renders full view buffer with header and footer" do
    app = ShowcaseAppModel.new
    view_out = app.view
    view_out.should contain("OPAL TUI SHOWCASE")
    view_out.should contain("Slide 1/23")
    view_out.should contain("Next")
    view_out.should contain("Quit")
  end
end
