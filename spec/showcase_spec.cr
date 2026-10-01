require "./spec_helper"
require "../examples/10_opal_tui_showcase"

describe ShowcaseAppModel do
  it "initializes with 16 slides" do
    app = ShowcaseAppModel.new
    app.slides.size.should eq(16)
    app.current_idx.should eq(0)
  end

  it "renders every single slide without error" do
    app = ShowcaseAppModel.new
    buf = Opal::UI::Buffer.new(90, 26)

    app.slides.each do |slide|
      buf.clear
      slide.render(buf, 0, 2, 90, 22)
      rendered = buf.render_to_string(with_ansi: false)
      rendered.should_not be_empty
    end
  end

  it "advances linearly through all slides via Shift+Right key" do
    app = ShowcaseAppModel.new
    shift_right_msg = Opal::TEA::KeyMsg.new("right", shift: true)

    16.times do |step|
      app.current_idx.should eq(step)
      app.update(shift_right_msg)
    end

    # Wraps around to 0
    app.current_idx.should eq(0)
  end

  it "supports backward navigation via Shift+Left" do
    app = ShowcaseAppModel.new
    app.update(Opal::TEA::KeyMsg.new("right", shift: true))
    app.current_idx.should eq(1)

    app.update(Opal::TEA::KeyMsg.new("left", shift: true))
    app.current_idx.should eq(0)
  end

  it "quits on escape key" do
    app = ShowcaseAppModel.new
    _model, cmd = app.update(Opal::TEA::KeyMsg.new("escape"))
    cmd.quit?.should be_true
  end

  it "renders full view buffer with header and footer" do
    app = ShowcaseAppModel.new
    view_out = app.view
    view_out.should contain("OPAL TUI")
    view_out.should contain("Slide 1/16")
    view_out.should contain("Next")
    view_out.should contain("Code")
    view_out.should contain("Guide")
  end

  it "operates checklist and launches on Slide 1 (CheckSlide)" do
    app = ShowcaseAppModel.new
    slide = app.slides[0].as(CheckSlide)
    initial_check = slide.checklist[0][:checked]

    # Toggle item
    slide.handle_key(Opal::Terminal::KeyEvent.new("space", ' '))
    slide.checklist[0][:checked].should eq(!initial_check)

    # Press Enter
    slide.handle_key(Opal::Terminal::KeyEvent.new("enter", '\n'))
    slide.launch_requested?.should be_true

    # App tick advances to Slide 2
    app.update(Opal::TEA::TickMsg.new)
    app.current_idx.should eq(1)
  end

  it "toggles feather and moves light on Slide 2 (SpotlightSlide)" do
    app = ShowcaseAppModel.new
    slide = app.slides[1].as(SpotlightSlide)
    orig_feather = slide.feather?

    slide.handle_key(Opal::Terminal::KeyEvent.new("f", 'f'))
    slide.feather?.should eq(!orig_feather)

    orig_x = slide.center_x
    slide.handle_key(Opal::Terminal::KeyEvent.new("d", 'd'))
    slide.center_x.should be > orig_x
  end

  it "toggles source code viewer modal with 'c'" do
    app = ShowcaseAppModel.new
    app.show_code?.should be_false

    # Press 'c' to open code viewer
    app.update(Opal::TEA::KeyMsg.new("c", 'c'))
    app.show_code?.should be_true
    app.code_viewer.should_not be_nil

    # Press 'escape' to close code viewer
    app.update(Opal::TEA::KeyMsg.new("escape"))
    app.show_code?.should be_false
  end

  it "toggles markdown guide modal with '?'" do
    app = ShowcaseAppModel.new
    app.show_guide?.should be_false

    # Press '?' to open guide viewer
    app.update(Opal::TEA::KeyMsg.new("?", '?'))
    app.show_guide?.should be_true
    app.guide_viewer.should_not be_nil

    # Press 'escape' to close guide viewer
    app.update(Opal::TEA::KeyMsg.new("escape"))
    app.show_guide?.should be_false
  end
end
