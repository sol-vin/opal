require "./spec_helper"

describe Opal::Shader do
  it "applies StarfieldPass without error" do
    buf = Opal::UI::Buffer.new(20, 10)
    pass = Opal::Shader::StarfieldPass.new(speed: 1.0, count: 20)
    pass.apply(buf, buf, 1.5, 30_u64)
    # Check that at least some characters were placed
    has_stars = (0...10).any? do |y|
      (0...20).any? { |x| buf.get(x, y).char != ' ' }
    end
    has_stars.should be_true
  end

  it "applies RipplePass displacing and coloring buffer" do
    buf = Opal::UI::Buffer.new(20, 10)
    buf.put_string(5, 5, "Hello", fg: Opal::Color.white)
    pass = Opal::Shader::RipplePass.new(speed: 1.0)
    pass.apply(buf, buf, 0.5, 10_u64)

    # Some cells should have ripple effects
    has_ripples = (0...10).any? do |y|
      (0...20).any? { |x| buf.get(x, y).char != ' ' }
    end
    has_ripples.should be_true
  end

  it "applies TunnelPass and renders cyber tunnel rings" do
    buf = Opal::UI::Buffer.new(20, 10)
    pass = Opal::Shader::TunnelPass.new(speed: 1.0)
    pass.apply(buf, buf, 1.0, 20_u64)

    has_tunnel = (0...10).any? do |y|
      (0...20).any? { |x| ['▓', '░'].includes?(buf.get(x, y).char) }
    end
    has_tunnel.should be_true
  end

  it "chains new passes in a shader pipeline" do
    buf = Opal::UI::Buffer.new(20, 10)
    pipeline = Opal.shader_pipeline do |p|
      p.starfield(speed: 0.5, count: 10)
      p.ripple(speed: 1.0)
      p.tunnel(speed: 0.5)
    end

    pipeline.apply(buf, 1.0, 10_u64)
    buf.width.should eq(20)
  end

  it "computes accurate FastMath sin and cos" do
    (-10..10).each do |i|
      rad = i.to_f * 0.5
      Opal::Shader::FastMath.sin(rad).should be_close(Math.sin(rad), 0.02)
      Opal::Shader::FastMath.cos(rad).should be_close(Math.cos(rad), 0.02)
    end
  end

  it "applies RaymarchSpherePass and renders 3D sphere ramp" do
    buf = Opal::UI::Buffer.new(30, 15)
    pass = Opal::Shader::RaymarchSpherePass.new(speed: 1.0, radius: 0.8)
    pass.apply(buf, buf, 0.5, 10_u64)

    has_sphere = (0...15).any? do |y|
      (0...30).any? { |x| Opal::Shader::RaymarchSpherePass::RAMP.includes?(buf.get(x, y).char) && buf.get(x, y).char != ' ' }
    end
    has_sphere.should be_true
  end

  it "applies VoronoiPass and renders cellular boundaries" do
    buf = Opal::UI::Buffer.new(30, 15)
    pass = Opal::Shader::VoronoiPass.new(speed: 0.8, scale: 0.2)
    pass.apply(buf, buf, 1.0, 20_u64)

    has_cells = (0...15).any? do |y|
      (0...30).any? { |x| ['▓', '▒', '.'].includes?(buf.get(x, y).char) }
    end
    has_cells.should be_true
  end

  it "applies FractalLandscapePass and renders terrain layers" do
    buf = Opal::UI::Buffer.new(40, 15)
    pass = Opal::Shader::FractalLandscapePass.new(speed: 1.0)
    pass.apply(buf, buf, 0.5, 15_u64)

    has_terrain = (0...15).any? do |y|
      (0...40).any? { |x| ['█', '▓', '░', '/', '^'].includes?(buf.get(x, y).char) }
    end
    has_terrain.should be_true
  end

  it "applies AudioVisualizerPass and renders frequency bars" do
    buf = Opal::UI::Buffer.new(30, 10)
    pass = Opal::Shader::AudioVisualizerPass.new(speed: 1.0, bar_count: 8)
    pass.apply(buf, buf, 0.8, 25_u64)

    has_bars = (0...10).any? do |y|
      (0...30).any? { |x| ['█', '▔'].includes?(buf.get(x, y).char) }
    end
    has_bars.should be_true
  end

  it "chains new procedural shaders in pipeline" do
    buf = Opal::UI::Buffer.new(20, 10)
    p = Opal::Shader::Pipeline.new
      .plasma(scale: 0.1)
      .raymarch_sphere(radius: 0.5)
      .voronoi(scale: 0.1)
      .fractal_landscape
      .audio_visualizer(bar_count: 6)

    p.apply(buf, 1.0, 1_u64)
    buf.cells.size.should eq(200)
  end
end
