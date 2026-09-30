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
end
