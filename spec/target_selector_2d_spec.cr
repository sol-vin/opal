require "./spec_helper"

describe Opal::UI::TargetSelector2D do
  it "initializes with continuous ranges and default center" do
    target = Opal::UI::TargetSelector2D.new(
      x_range: -10.0..10.0,
      y_range: -5.0..5.0,
      width: 20,
      height: 10
    )
    target.x_val.should eq(0.0)
    target.y_val.should eq(0.0)
    u, v = target.normalized_coords
    u.should be_close(0.5, 0.01)
    v.should be_close(0.5, 0.01)
  end

  it "clamps set_values within bounds" do
    target = Opal::UI::TargetSelector2D.new(x_range: 0.0..1.0, y_range: 0.0..1.0)
    target.set_values(2.5, -1.0)
    target.x_val.should eq(1.0)
    target.y_val.should eq(0.0)
  end

  it "handles arrow key navigation" do
    target = Opal::UI::TargetSelector2D.new(
      x_range: 0.0..1.0,
      y_range: 0.0..1.0,
      initial_x: 0.5,
      initial_y: 0.5
    )

    key_right = Opal::Terminal::KeyEvent.new("right")
    target.handle_input(key_right).should be_true
    target.x_val.should be > 0.5

    key_down = Opal::Terminal::KeyEvent.new("down")
    target.handle_input(key_down).should be_true
    target.y_val.should be < 0.5
  end

  it "renders procedural background and reticle into buffer" do
    target = Opal::UI::TargetSelector2D.new(
      x_range: 0.0..10.0,
      y_range: 0.0..10.0,
      initial_x: 5.0,
      initial_y: 5.0,
      width: 16,
      height: 8
    ) do |u, v|
      Opal::Color.rgb((u * 255).round.to_i, 0, (v * 255).round.to_i)
    end

    buf = Opal::UI::Buffer.new(16, 8)
    target.render(buf, 0, 0, 16, 8)
    rendered = buf.render_to_string(with_ansi: false)

    # Contains reticle glyph '⌖'
    rendered.should contain("⌖")
    rendered.should contain("X:5.00")
  end

  it "integrates with DSL" do
    output = Opal.render_ui(width: 30, height: 12) do |ui|
      ui.target_selector_2d(width: 20, height: 8)
    end
    output.should contain("⌖")
  end
end
