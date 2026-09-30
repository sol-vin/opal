require "./spec_helper"

describe Opal::UI::ColorPicker do
  it "initializes with default color and channels" do
    picker = Opal::UI::ColorPicker.new(Opal::Color.rgb(100, 150, 200))
    picker.r.should eq(100)
    picker.g.should eq(150)
    picker.b.should eq(200)
    picker.hex_code.should eq("#6496C8")
  end

  it "adjusts active channel with clamping" do
    picker = Opal::UI::ColorPicker.new(Opal::Color.rgb(10, 10, 10), active_channel: :red)
    picker.adjust_active(20)
    picker.r.should eq(30)

    # Upper clamp
    picker.adjust_active(300)
    picker.r.should eq(255)

    # Lower clamp
    picker.adjust_active(-500)
    picker.r.should eq(0)
  end

  it "cycles active channels" do
    picker = Opal::UI::ColorPicker.new(active_channel: :red)
    picker.next_channel
    picker.active_channel.should eq(:green)

    picker.next_channel
    picker.active_channel.should eq(:blue)

    picker.next_channel
    picker.active_channel.should eq(:palette)

    picker.next_channel
    picker.active_channel.should eq(:red)

    picker.prev_channel
    picker.active_channel.should eq(:palette)
  end

  it "selects preset swatches" do
    picker = Opal::UI::ColorPicker.new
    picker.select_preset(0)
    expected_c = Opal::UI::ColorPicker::DEFAULT_PALETTE[0]
    picker.color.to_rgb.should eq(expected_c.to_rgb)
  end

  it "calculates relative luminance" do
    black_picker = Opal::UI::ColorPicker.new(Opal::Color.rgb(0, 0, 0))
    black_picker.luminance.should eq(0.0)

    white_picker = Opal::UI::ColorPicker.new(Opal::Color.rgb(255, 255, 255))
    white_picker.luminance.should be_close(1.0, 0.01)
  end

  it "handles key events" do
    picker = Opal::UI::ColorPicker.new(Opal::Color.rgb(50, 50, 50), active_channel: :red)
    key_right = Opal::Terminal::KeyEvent.new("right")
    picker.handle_key(key_right).should be_true
    picker.r.should eq(55)

    key_tab = Opal::Terminal::KeyEvent.new("tab")
    picker.handle_key(key_tab).should be_true
    picker.active_channel.should eq(:green)

    key_num = Opal::Terminal::KeyEvent.new("1")
    picker.handle_key(key_num).should be_true
  end

  it "renders into a buffer without errors" do
    picker = Opal::UI::ColorPicker.new(Opal::Color.hex("#89B4FA"))
    buf = Opal::UI::Buffer.new(50, 16)
    picker.render(buf, 0, 0, 50, 16)
    rendered = buf.render_to_string(with_ansi: false)

    rendered.should contain("Color Picker")
    rendered.should contain("Hex: #89B4FA")
    rendered.should contain("[R]")
    rendered.should contain("[G]")
    rendered.should contain("[B]")
    rendered.should contain("Presets:")
  end

  it "integrates with DSL builder" do
    output = Opal.render_ui(width: 50, height: 16) do |ui|
      ui.color_picker
    end
    output.should contain("Color Picker")
  end

  it "responds to mouse clicks on preset palette swatches" do
    picker = Opal::UI::ColorPicker.new
    buf = Opal::UI::Buffer.new(60, 20)
    picker.render(buf, 0, 0, 60, 20)

    # Click on preset swatch 2
    swatch_idx = 2
    swatch_x = picker.last_preset_start_x + (swatch_idx * 3) + 1 # Click on the block
    swatch_y = picker.last_preset_y + 1                          # 1-indexed terminal coordinate

    ev_click = Opal::Terminal::MouseEvent.new(swatch_x, swatch_y, Opal::Terminal::MouseButton::Left, Opal::Terminal::MouseAction::Press)
    picker.handle_mouse(ev_click).should be_true

    picker.active_channel.should eq(:palette)
    picker.palette_cursor.should eq(swatch_idx)
    expected_c = picker.preset_swatches[swatch_idx]
    picker.color.to_rgb.should eq(expected_c.to_rgb)
  end

  it "responds to mouse clicks and dragging on color choice bars" do
    picker = Opal::UI::ColorPicker.new(Opal::Color.rgb(0, 0, 0))
    buf = Opal::UI::Buffer.new(60, 20)
    picker.render(buf, 0, 0, 60, 20)

    slider_x = picker.last_slider_x
    track_w = picker.last_track_w
    red_y = picker.last_red_y + 1 # 1-indexed

    # Click at 50% along the red slider bar
    mid_x = slider_x + 1 + (track_w // 2)
    ev_click = Opal::Terminal::MouseEvent.new(mid_x, red_y, Opal::Terminal::MouseButton::Left, Opal::Terminal::MouseAction::Press)
    picker.handle_mouse(ev_click).should be_true

    picker.active_channel.should eq(:red)
    picker.r.should be_close(128, 20)

    # Drag to the end of the red slider bar (100%)
    end_x = slider_x + 1 + track_w
    ev_drag = Opal::Terminal::MouseEvent.new(end_x, red_y, Opal::Terminal::MouseButton::Left, Opal::Terminal::MouseAction::Motion)
    picker.handle_mouse(ev_drag).should be_true
    picker.r.should eq(255)

    # Release
    ev_release = Opal::Terminal::MouseEvent.new(end_x, red_y, Opal::Terminal::MouseButton::Left, Opal::Terminal::MouseAction::Release)
    picker.handle_mouse(ev_release).should be_true

    # Click on Green slider choice bar at start (0%)
    green_y = picker.last_green_y + 1
    ev_click_green = Opal::Terminal::MouseEvent.new(slider_x + 1, green_y, Opal::Terminal::MouseButton::Left, Opal::Terminal::MouseAction::Press)
    picker.handle_mouse(ev_click_green).should be_true
    picker.active_channel.should eq(:green)
    picker.g.should eq(0)
  end

  it "adjusts color choice bars with mouse wheel" do
    picker = Opal::UI::ColorPicker.new(Opal::Color.rgb(100, 100, 100))
    buf = Opal::UI::Buffer.new(60, 20)
    picker.render(buf, 0, 0, 60, 20)

    blue_y = picker.last_blue_y + 1
    ev_wheel_up = Opal::Terminal::MouseEvent.new(picker.last_slider_x + 2, blue_y, Opal::Terminal::MouseButton::WheelUp, Opal::Terminal::MouseAction::Press)
    picker.handle_mouse(ev_wheel_up).should be_true
    picker.active_channel.should eq(:blue)
    picker.b.should eq(105)

    ev_wheel_down = Opal::Terminal::MouseEvent.new(picker.last_slider_x + 2, blue_y, Opal::Terminal::MouseButton::WheelDown, Opal::Terminal::MouseAction::Press)
    picker.handle_mouse(ev_wheel_down).should be_true
    picker.b.should eq(100)
  end
end
