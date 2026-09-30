require "./spec_helper"

describe Opal::UI::PieChart do
  it "calculates total value and slice percentages correctly" do
    chart = Opal::UI::PieChart.new(title: "Memory Allocation")
    chart.add("Used", 60.0, :red)
    chart.add("Cached", 20.0, :yellow)
    chart.add("Free", 20.0, :green)

    chart.total_value.should eq(100.0)
    chart.slices.size.should eq(3)
  end

  it "renders circular pie chart and legend into buffer" do
    chart = Opal::UI::PieChart.new(title: "Cloud Regions")
    chart.add("us-east", 50.0, :cyan)
    chart.add("eu-west", 30.0, :green)
    chart.add("ap-south", 20.0, :magenta)

    buf = Opal::UI::Buffer.new(70, 16)
    chart.render(buf, 0, 0, 70, 16)

    rendered = buf.render_to_string(with_ansi: false)
    rendered.should contain("Cloud Regions")
    rendered.should contain("Distribution:")
    rendered.should contain("us-east")
    rendered.should contain("eu-west")
    rendered.should contain("ap-south")
    rendered.should contain("50.0%")
    rendered.should contain("30.0%")
    rendered.should contain("20.0%")
  end

  it "renders donut pie chart with center total label" do
    chart = Opal::UI::PieChart.new(title: "Disk Usage", donut: true)
    chart.add("Data", 80.0, :blue)
    chart.add("Logs", 20.0, :yellow)

    buf = Opal::UI::Buffer.new(70, 16)
    chart.render(buf, 0, 0, 70, 16)

    rendered = buf.render_to_string(with_ansi: false)
    rendered.should contain("Disk Usage")
    rendered.should contain("100") # Center total
  end

  it "builds cleanly through DSL" do
    ui = Opal.render_ui(70, 16) do |u|
      u.pie_chart("Services Breakdown", donut: true) do |p|
        p.slice("API", 45, :cyan)
        p.slice("DB", 35, :magenta)
        p.slice("Queue", 20, :green)
      end
    end

    ui.should contain("Services Breakdown")
    ui.should contain("API")
    ui.should contain("DB")
    ui.should contain("Queue")
  end
end
