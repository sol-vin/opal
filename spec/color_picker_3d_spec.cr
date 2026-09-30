require "./spec_helper"

describe Opal::UI::ColorPicker3D do
  it "initializes with 3D RGB Cube by default" do
    picker = Opal::UI::ColorPicker3D.new
    picker.shape.should eq(Opal::UI::ColorPickerShape::Cube3D)
    picker.pitch.should be_close(0.42, 0.01)
    picker.yaw.should be_close(0.58, 0.01)
  end

  it "cycles through 3D and 2D shapes" do
    picker = Opal::UI::ColorPicker3D.new
    picker.shape.should eq(Opal::UI::ColorPickerShape::Cube3D)

    picker.cycle_shape
    picker.shape.should eq(Opal::UI::ColorPickerShape::Sphere3D)

    picker.cycle_shape
    picker.shape.should eq(Opal::UI::ColorPickerShape::Circle2D)

    picker.cycle_shape
    picker.shape.should eq(Opal::UI::ColorPickerShape::Square2D)

    picker.cycle_shape
    picker.shape.should eq(Opal::UI::ColorPickerShape::Cube3D)
  end

  it "converts HSL to RGB accurately" do
    # Red: Hue=0, Sat=1.0, Light=0.5
    red = Opal::UI::ColorPicker3D.hsl_to_rgb(0.0, 1.0, 0.5)
    red.to_rgb.should eq({255_u8, 0_u8, 0_u8})

    # Green: Hue=120, Sat=1.0, Light=0.5
    green = Opal::UI::ColorPicker3D.hsl_to_rgb(120.0, 1.0, 0.5)
    green.to_rgb.should eq({0_u8, 255_u8, 0_u8})

    # Blue: Hue=240, Sat=1.0, Light=0.5
    blue = Opal::UI::ColorPicker3D.hsl_to_rgb(240.0, 1.0, 0.5)
    blue.to_rgb.should eq({0_u8, 0_u8, 255_u8})
  end

  it "handles 3D rotation and virtual cursor keys" do
    picker = Opal::UI::ColorPicker3D.new
    init_pitch = picker.pitch
    init_yaw = picker.yaw

    # W/S turns pitch
    picker.handle_key(Opal::Terminal::KeyEvent.new("w")).should be_true
    (picker.pitch < init_pitch).should be_true

    # A/D turns yaw
    picker.handle_key(Opal::Terminal::KeyEvent.new("d")).should be_true
    (picker.yaw > init_yaw).should be_true

    # Arrow keys move virtual raycast cursor
    init_cx = picker.cursor_x
    picker.handle_key(Opal::Terminal::KeyEvent.new("right")).should be_true
    picker.cursor_x.should eq(init_cx + 1)
  end

  it "renders 3D cube and raycasts colors into buffer" do
    picker = Opal::UI::ColorPicker3D.new
    buf = Opal::UI::Buffer.new(65, 18)
    picker.render(buf, 0, 0, 65, 18)

    rendered = buf.render_to_string(with_ansi: false)
    rendered.should contain("2D/3D Color Spectrum Studio")
    rendered.should contain("3D RGB Cube")
    rendered.should contain("Selected Swatch:")
    rendered.should contain("Hex:")
    rendered.should contain("RGB:")

    # Virtual cursor crosshair '✛' should be on canvas
    rendered.should contain("✛")
  end

  it "renders 2D polar circle wheel" do
    picker = Opal::UI::ColorPicker3D.new(shape: Opal::UI::ColorPickerShape::Circle2D)
    buf = Opal::UI::Buffer.new(65, 18)
    picker.render(buf, 0, 0, 65, 18)

    rendered = buf.render_to_string(with_ansi: false)
    rendered.should contain("2D Polar Wheel")
  end

  it "integrates with DSL builder" do
    output = Opal.render_ui(width: 60, height: 16) do |ui|
      ui.color_picker_3d
    end
    output.should contain("Color Spectrum Studio")
  end
end
