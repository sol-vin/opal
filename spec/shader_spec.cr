require "./spec_helper"

describe Opal::Shader do
  it "evaluates procedural fragment shaders on buffer" do
    buf = Opal::UI::Buffer.new(20, 10)
    buf.put_string(0, 0, "Hello Opal Shader!")

    buf.shade do |c|
      if c.x < 5
        c.char = '*'
        c.fg = Opal::Color.green
      end
    end

    buf.get(0, 0).char.should eq('*')
    buf.get(0, 0).fg.to_rgb.should eq(Opal::Color.green.to_rgb)
    # Beyond x=5 should be untouched
    buf.get(6, 0).char.should eq('O')
  end

  it "restricts shader passes to a designated region" do
    buf = Opal::UI::Buffer.new(30, 20)
    buf.fill(0, 0, 30, 20, Opal::UI::Cell.new('.'))

    region = Opal::Shader::Rect.new(5, 5, 10, 5)
    buf.shade(region: region) do |c|
      c.char = 'X'
    end

    # Inside region
    buf.get(5, 5).char.should eq('X')
    buf.get(14, 9).char.should eq('X')

    # Outside region
    buf.get(4, 5).char.should eq('.')
    buf.get(15, 9).char.should eq('.')
    buf.get(5, 4).char.should eq('.')
    buf.get(5, 10).char.should eq('.')
  end

  it "computes math helpers: UVs, wave, noise, dist_center" do
    buf = Opal::UI::Buffer.new(10, 10)
    tested = false

    buf.shade do |c|
      if c.x == 5 && c.y == 5
        c.u.should be_close(0.55, 0.05)
        c.v.should be_close(0.55, 0.05)
        c.dist_center.should be_close(0.15, 0.1)
        (c.noise >= 0.0 && c.noise <= 1.0).should be_true
        (c.wave(1.0) >= -1.0 && c.wave(1.0) <= 1.0).should be_true
        tested = true
      end
    end

    tested.should be_true
  end

  it "chains multi-pass compositing pipelines" do
    buf = Opal::UI::Buffer.new(20, 10)
    buf.put_string(0, 0, "Original Content")

    pipeline = Opal.shader_pipeline do |p|
      # Pass 1: Replace spaces
      p.custom do |c|
        c.char = '#' if c.char == ' '
      end

      # Pass 2: Tint foreground
      p.custom do |c|
        c.fg = Opal::Color.cyan
      end
    end

    pipeline.apply(buf)

    buf.get(0, 0).fg.to_rgb.should eq(Opal::Color.cyan.to_rgb)
    buf.get(8, 0).char.should eq('#')
  end

  it "applies built-in MatrixPass" do
    buf = Opal::UI::Buffer.new(20, 10)
    pass = Opal::Shader::MatrixPass.new(speed: 1.0)
    pass.apply(buf, buf, time: 1.5, frame: 10_u64)

    # Some cells should contain matrix characters
    has_matrix_char = (0...10).any? do |y|
      (0...20).any? { |x| Opal::Shader::MatrixPass::MATRIX_CHARS.includes?(buf.get(x, y).char) }
    end
    has_matrix_char.should be_true
  end

  it "applies built-in CrtPass" do
    buf = Opal::UI::Buffer.new(20, 10)
    buf.put_string(0, 0, "CRT Screen Test", fg: Opal::Color.white)
    buf.put_string(0, 2, "Line Two", fg: Opal::Color.white)

    pass = Opal::Shader::CrtPass.new(intensity: 0.5, scanline_gap: 2)
    pass.apply(buf, buf, time: 0.0, frame: 0_u64)

    # Line 0 (even) should be dimmed by scanline
    buf.get(0, 0).dim?.should be_true
  end

  it "applies built-in PlasmaPass" do
    buf = Opal::UI::Buffer.new(15, 10)
    pass = Opal::Shader::PlasmaPass.new(scale: 0.3)
    pass.apply(buf, buf, time: 2.0, frame: 20_u64)

    # Cells should have TrueColor RGB set
    buf.get(5, 5).fg.type.should eq(Opal::Color::Type::RGB)
  end
end
