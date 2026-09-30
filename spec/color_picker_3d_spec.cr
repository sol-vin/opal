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

  it "renders 3D cube and sphere with solid continuous surface coverage without gaps" do
    picker = Opal::UI::ColorPicker3D.new(shape: Opal::UI::ColorPickerShape::Cube3D)
    buf = Opal::UI::Buffer.new(70, 20)
    picker.render(buf, 0, 0, 70, 20)

    rendered = buf.render_to_string(with_ansi: false)
    cube_blocks = rendered.count('█')
    # Dense sampling produces substantial solid block coverage
    cube_blocks.should be > 100

    # Check sphere
    picker.cycle_shape # Sphere3D
    buf.clear
    picker.render(buf, 0, 0, 70, 20)
    rendered_sphere = buf.render_to_string(with_ansi: false)
    sphere_blocks = rendered_sphere.count('█')
    sphere_blocks.should be > 100
  end

  it "handles right-click drag to rotate pitch and yaw" do
    picker = Opal::UI::ColorPicker3D.new
    init_pitch = picker.pitch
    init_yaw = picker.yaw

    # Press right button
    ev_press = Opal::Terminal::MouseEvent.new(20, 10, Opal::Terminal::MouseButton::Right, Opal::Terminal::MouseAction::Press)
    picker.handle_mouse(ev_press).should be_true

    # Drag right button
    ev_drag = Opal::Terminal::MouseEvent.new(25, 14, Opal::Terminal::MouseButton::Right, Opal::Terminal::MouseAction::Motion)
    picker.handle_mouse(ev_drag).should be_true

    picker.yaw.should be > init_yaw
    picker.pitch.should be > init_pitch

    # Release right button
    ev_release = Opal::Terminal::MouseEvent.new(25, 14, Opal::Terminal::MouseButton::Right, Opal::Terminal::MouseAction::Release)
    picker.handle_mouse(ev_release).should be_true
  end

  it "handles left-click to choose color from surface using raycast" do
    picker = Opal::UI::ColorPicker3D.new(shape: Opal::UI::ColorPickerShape::Cube3D)
    buf = Opal::UI::Buffer.new(70, 20)
    picker.render(buf, 0, 0, 70, 20)

    # Click on the center of the 3D cube canvas
    cx = picker.last_canvas_x
    cy = picker.last_canvas_y
    cw = picker.last_canvas_w
    ch = picker.last_canvas_h

    # Click near the center of the 3D cube
    click_x = cx + 1 + (cw // 2)
    click_y = cy + 1 + (ch // 2)
    ev_click = Opal::Terminal::MouseEvent.new(click_x, click_y, Opal::Terminal::MouseButton::Left, Opal::Terminal::MouseAction::Press)

    picker.handle_mouse(ev_click).should be_true
    picker.cursor_x.should eq(cw // 2)
    picker.cursor_y.should eq(ch // 2)

    # The selected color should be non-empty RGB from the cube surface
    r, g, b = picker.selected_color.to_rgb
    (r > 0 || g > 0 || b > 0).should be_true

    # Test raycasting on 3D Sphere as well
    picker.shape = Opal::UI::ColorPickerShape::Sphere3D
    picker.render(buf, 0, 0, 70, 20)

    prev_color = picker.selected_color
    # Click on sphere surface
    ev_click_sphere = Opal::Terminal::MouseEvent.new(click_x, click_y, Opal::Terminal::MouseButton::Left, Opal::Terminal::MouseAction::Press)
    picker.handle_mouse(ev_click_sphere).should be_true

    sphere_r, sphere_g, sphere_b = picker.selected_color.to_rgb
    (sphere_r > 0 || sphere_g > 0 || sphere_b > 0).should be_true
  end

  it "provides direct mathematical raycast sampling via sample_raycast_color" do
    picker = Opal::UI::ColorPicker3D.new(shape: Opal::UI::ColorPickerShape::Cube3D)
    # Center of cube should always hit surface
    center_color = picker.sample_raycast_color(14, 6, 28, 12)
    center_color.should_not be_nil

    # Far corner (lx: 0, ly: 0) is outside the cube silhouette
    corner_color = picker.sample_raycast_color(0, 0, 28, 12)
    corner_color.should be_nil
  end
end
