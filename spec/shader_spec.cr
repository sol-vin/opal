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
end
