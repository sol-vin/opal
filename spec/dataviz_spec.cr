require "./spec_helper"

describe "Opal Data Visualization Components" do
  it "renders a Sparkline to string with correct block characters" do
    data = [0.0, 50.0, 100.0]
    out = Opal::UI::Sparkline.render_to_string(data)
    out.should eq(" ▅█")
  end

  it "renders a Sparkline into a Buffer" do
    buf = Opal::UI::Buffer.new(10, 2)
    spark = Opal::UI::Sparkline.new(data: [10.0, 20.0, 30.0], title: "CPU")
    spark.render(buf, 0, 0, 10, 2)

    str = buf.to_s
    str.should contain("CPU")
  end

  it "renders a BarChart with auto-scaling and labels" do
    buf = Opal::UI::Buffer.new(30, 5)
    chart = Opal::UI::BarChart.new(title: "Tasks")
    chart.add("App", 50.0)
    chart.add("Db", 100.0)
    chart.render(buf, 0, 0, 30, 5)

    str = buf.to_s
    str.should contain("Tasks")
    str.should contain("App")
    str.should contain("Db")
    str.should contain("█")
  end

  it "renders a Gauge with percentage and indicators" do
    buf = Opal::UI::Buffer.new(25, 1)
    gauge = Opal::UI::Gauge.new(0.75, label: "RAM")
    gauge.render(buf, 0, 0, 25, 1)

    str = buf.to_s
    str.should contain("RAM")
    str.should contain("75%")
    str.should contain("[")
    str.should contain("]")
  end

  it "renders a Tree hierarchy with connectors" do
    buf = Opal::UI::Buffer.new(30, 6)
    tree = Opal::UI::Tree.new(title: "Project")
    tree.add("src") do |src|
      src.add("main.cr")
      src.add("utils.cr")
    end
    tree.render(buf, 0, 0, 30, 6)

    str = buf.to_s
    str.should contain("Project")
    str.should contain("src")
    str.should contain("main.cr")
    str.should contain("utils.cr")
    str.should contain("├──")
    str.should contain("└──")
  end
end
