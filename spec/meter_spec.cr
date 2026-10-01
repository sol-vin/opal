require "./spec_helper"

describe "Opal::UI::Meter Subsystem" do
  it "renders horizontal 1/8th fractional block meters" do
    meter = Opal::UI::Meter.new(value: 0.5, show_label: false, width: 10, height: 1)
    buf = Opal::UI::Buffer.new(10, 1)
    meter.render(buf, 0, 0, 10, 1)

    # At 50% across 10 cells, first 5 cells should be full blocks '█', remaining empty ' '
    (0...5).each do |x|
      buf.get(x, 0).char.should eq('█')
    end
    (5...10).each do |x|
      buf.get(x, 0).char.should eq(' ')
    end
  end

  it "renders vertical fractional meters" do
    meter = Opal::UI::Meter.new(value: 0.5, orientation: Opal::UI::MeterOrientation::Vertical, width: 1, height: 10)
    buf = Opal::UI::Buffer.new(1, 10)
    meter.render(buf, 0, 0, 1, 10)

    # In vertical 50% across 10 rows: bottom 5 rows filled, top 5 rows empty
    (0...5).each do |y|
      buf.get(0, y).char.should eq(' ')
    end
    (5...10).each do |y|
      buf.get(0, y).char.should eq('█')
    end
  end

  it "renders compact 1-character meter via DSL" do
    builder = Opal::UI::Builder.new
    cm = builder.compact_meter(0.5)
    cm.content.should eq("▌")
  end
end
