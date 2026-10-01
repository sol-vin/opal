require "./spec_helper"
require "../examples/10_opal_tui_showcase"

describe ShowcaseAppModel do
  it "initializes with 34 slides" do
    app = ShowcaseAppModel.new
    app.slides.size.should eq(34)
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

  it "advances linearly through all slides via Shift+Right key" do
    app = ShowcaseAppModel.new
    shift_right_msg = Opal::TEA::KeyMsg.new("right", shift: true)

    34.times do |step|
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
    view_out.should contain("OPAL TUI SHOWCASE")
    view_out.should contain("Slide 1/34")
    view_out.should contain("Next")
    view_out.should contain("Quit")
  end

  it "cycles modes on Slide 32 (DslBlendingSlide)" do
    app = ShowcaseAppModel.new
    slide = app.slides[31].as(DslBlendingSlide)
    slide.mode.should eq(1)

    slide.handle_key(Opal::Terminal::KeyEvent.new("2", '2'))
    slide.mode.should eq(2)

    slide.handle_key(Opal::Terminal::KeyEvent.new("3", '3'))
    slide.mode.should eq(3)

    slide.handle_key(Opal::Terminal::KeyEvent.new("space", ' '))
    slide.mode.should eq(1)
  end

  it "operates tape controls on Slide 33 (VcrTapeDeckSlide)" do
    app = ShowcaseAppModel.new
    slide = app.slides[32].as(VcrTapeDeckSlide)
    slide.vcr_state.should eq(VcrTapeDeckSlide::VcrState::Playing)

    # Pause
    slide.handle_key(Opal::Terminal::KeyEvent.new("p", 'p'))
    slide.vcr_state.should eq(VcrTapeDeckSlide::VcrState::Paused)

    # Stop
    slide.handle_key(Opal::Terminal::KeyEvent.new("s", 's'))
    slide.vcr_state.should eq(VcrTapeDeckSlide::VcrState::Stopped)

    # Record
    slide.handle_key(Opal::Terminal::KeyEvent.new("r", 'r'))
    slide.vcr_state.should eq(VcrTapeDeckSlide::VcrState::Recording)

    # Toggle overlay
    orig_overlay = slide.respect_overlays
    slide.handle_key(Opal::Terminal::KeyEvent.new("o", 'o'))
    slide.respect_overlays.should eq(!orig_overlay)
  end

  it "toggles donut mode on slide 10 (PieChartSlide) when pressing space" do
    app = ShowcaseAppModel.new
    # Navigate to slide 10 (index 9)
    9.times do
      app.update(Opal::TEA::KeyMsg.new("right", shift: true))
    end
    app.current_idx.should eq(9)
    slide = app.slides[9].as(PieChartSlide)
    slide.donut_mode?.should be_false

    # Press spacebar with key name "space"
    app.update(Opal::TEA::KeyMsg.new("space", ' '))
    slide.donut_mode?.should be_true

    # Press spacebar again
    app.update(Opal::TEA::KeyMsg.new("space", ' '))
    slide.donut_mode?.should be_false

    # Press spacebar with key name " " (raw single space)
    app.update(Opal::TEA::KeyMsg.new(" ", ' '))
    slide.donut_mode?.should be_true

    # Click with mouse
    app.update(Opal::TEA::MouseMsg.new(30, 10, Opal::Terminal::MouseButton::Left, Opal::Terminal::MouseAction::Press))
    slide.donut_mode?.should be_false
  end
end
