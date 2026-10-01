require "./spec_helper"

describe Opal::UI::EquationViewer do
  it "formats Unicode superscripts and subscripts" do
    formatted = Opal::UI::EquationViewer.format_super_sub("x^2 + y_1 = z^(n+1)")
    formatted.should eq("x² + y₁ = zⁿ⁺¹")
  end

  it "renders fractions and integrals in 2D math layout" do
    viewer = Opal::UI::EquationViewer.new(function_title: "Calculus", width: 44, height: 16)
    viewer.add_fraction("sin(x)", "1 + x²")
    viewer.add_integral("0", "π", "cos(t) dt")

    buf = Opal::UI::Buffer.new(44, 16)
    viewer.render(buf, 0, 0, 44, 16)
    rendered = buf.render_to_string(with_ansi: false)

    rendered.should contain("sin(x)")
    rendered.should contain("1 + x²")
    rendered.should contain("cos(t) dt")
    rendered.should contain("Calculus")
  end

  it "plots Cartesian function with braille curves" do
    viewer = Opal::UI::EquationViewer.new("f(x) = x²", -2.0, 2.0, -1.0, 4.0, width: 40, height: 14) do |x|
      x * x
    end

    buf = Opal::UI::Buffer.new(40, 14)
    viewer.render(buf, 0, 0, 40, 14)
    rendered = buf.render_to_string(with_ansi: false)

    rendered.should contain("f(x) = x²")
    # Verify origin cross or axis was drawn
    (rendered.includes?('┼') || rendered.includes?('─')).should be_true
  end

  it "handles zoom and pan keys" do
    viewer = Opal::UI::EquationViewer.new("f(x) = x", -5.0, 5.0, -5.0, 5.0)
    initial_span_x = viewer.x_max - viewer.x_min

    # Zoom in
    viewer.handle_key(Opal::Terminal::KeyEvent.new("+")).should be_true
    (viewer.x_max - viewer.x_min).should be < initial_span_x

    # Pan right
    prev_min = viewer.x_min
    viewer.handle_key(Opal::Terminal::KeyEvent.new("right")).should be_true
    viewer.x_min.should be > prev_min
  end

  it "integrates with DSL" do
    output = Opal.render_ui(width: 44, height: 16) do |ui|
      ui.equation_viewer("f(x) = 2x") do |x|
        2.0 * x
      end
    end
    output.should contain("f(x) = 2x")
  end
end
