require "./spec_helper"

describe Opal::UI::CurveEditor do
  it "initializes with default control points" do
    editor = Opal::UI::CurveEditor.new(0.42, 0.0, 0.58, 1.0)
    editor.p1_x.should eq(0.42)
    editor.p1_y.should eq(0.0)
    editor.p2_x.should eq(0.58)
    editor.p2_y.should eq(1.0)
    editor.to_css.should eq("cubic-bezier(0.42, 0.00, 0.58, 1.00)")
  end

  it "switches active handle with Tab and 1/2" do
    editor = Opal::UI::CurveEditor.new
    editor.active_handle.should eq(1)

    editor.handle_key(Opal::Terminal::KeyEvent.new("tab")).should be_true
    editor.active_handle.should eq(2)

    editor.handle_key(Opal::Terminal::KeyEvent.new("1")).should be_true
    editor.active_handle.should eq(1)
  end

  it "loads standard presets" do
    editor = Opal::UI::CurveEditor.new
    editor.preset("ease")
    editor.to_css.should eq("cubic-bezier(0.25, 0.10, 0.25, 1.00)")

    editor.preset("linear")
    editor.to_css.should eq("cubic-bezier(0.00, 0.00, 1.00, 1.00)")
  end

  it "evaluates easing progression" do
    editor = Opal::UI::CurveEditor.new(0.0, 0.0, 1.0, 1.0) # linear
    editor.evaluate_easing(0.0).should eq(0.0)
    editor.evaluate_easing(0.5).should be_close(0.5, 0.05)
    editor.evaluate_easing(1.0).should eq(1.0)
  end

  it "renders braille curve and ease track into buffer" do
    editor = Opal::UI::CurveEditor.new(0.25, 0.1, 0.25, 1.0, width: 36, height: 14)
    buf = Opal::UI::Buffer.new(36, 14)
    editor.render(buf, 0, 0, 36, 14)
    rendered = buf.render_to_string(with_ansi: false)

    rendered.should contain("cubic-bezier")
    rendered.should contain("Ease Track:")
    rendered.should contain("P1:")
    rendered.should contain("P2:")
  end

  it "integrates with DSL" do
    output = Opal.render_ui(width: 40, height: 16) do |ui|
      ui.curve_editor
    end
    output.should contain("cubic-bezier")
  end
end
