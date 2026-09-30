require "./spec_helper"

describe Opal::UI::LineGraph do
  it "manages series and data points" do
    graph = Opal::UI::LineGraph.new(title: "Latency Telemetry")
    s1 = graph.add_series("p99", [12.0, 15.0, 18.0, 14.0], :red)
    s2 = graph.add_series("p50", [2.0, 3.0, 2.5, 3.1], :green)

    graph.series.size.should eq(2)
    s1.data.size.should eq(4)
    s2.push(2.8)
    s2.data.size.should eq(5)
  end

  it "renders Cartesian axes and series lines" do
    graph = Opal::UI::LineGraph.new(title: "Network Throughput", min_y: 0.0, max_y: 100.0)
    graph.add_series("Inbound", [10.0, 25.0, 45.0, 70.0, 85.0, 90.0, 60.0], :cyan)

    buf = Opal::UI::Buffer.new(70, 14)
    graph.render(buf, 0, 0, 70, 14)

    rendered = buf.render_to_string(with_ansi: false)
    rendered.should contain("Network Throughput")
    rendered.should contain("Inbound")
    rendered.should contain("100") # Top tick
    rendered.should contain("0")   # Bottom tick
  end

  it "builds cleanly through DSL" do
    ui = Opal.render_ui(70, 14) do |u|
      u.line_graph("CPU Load History", min_y: 0.0, max_y: 100.0) do |g|
        g.series("Core 0", [20.0, 40.0, 65.0, 30.0], :yellow)
        g.series("Core 1", [15.0, 35.0, 50.0, 25.0], :cyan)
      end
    end

    ui.should contain("CPU Load History")
    ui.should contain("Core 0")
    ui.should contain("Core 1")
  end
end
