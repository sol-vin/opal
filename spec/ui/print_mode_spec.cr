require "../spec_helper"

describe "Opal UI Print Mode" do
  describe Opal::UI::Table do
    it "renders to print string with headers and rows" do
      table = Opal::UI::Table.new(["Name", "Role", "Department"])
      table.add_row(["Alice", "Engineer", "Platform"])
      table.add_row(["Bob", "Designer", "UX"])

      output = table.to_print_s(width: 60)
      output.should contain("Alice")
      output.should contain("Bob")
      output.should contain("Engineer")
      output.should contain("Platform")
      output.should contain("UX")
    end

    it "supports different border styles in print mode" do
      headers = ["Item", "Qty"]
      rows = [["Apples", "5"]]

      # Rounded
      rounded = Opal::UI::Table.to_string(headers, rows, border_style: :rounded, width: 40)
      rounded.should contain("╭")
      rounded.should contain("╰")

      # Ascii
      ascii = Opal::UI::Table.to_string(headers, rows, border_style: :ascii, width: 40)
      ascii.should contain("+")
      ascii.should contain("|")

      # Markdown
      md = Opal::UI::Table.to_string(headers, rows, border_style: :markdown, width: 40)
      md.should contain("| Item")
      md.should contain("|:---")
    end

    it "expands to preferred print size without truncation" do
      table = Opal::UI::Table.new(["ID", "Name"], border_style: :rounded)
      10.times { |i| table.add_row(["#{i}", "User #{i}"]) }

      pref_w, pref_h = table.preferred_print_size(80)
      pref_h.should eq(14) # 1 top + 1 header + 1 divider + 10 rows + 1 bottom
      output = table.to_print_s(width: 80)
      output.lines.size.should eq(pref_h)
    end
  end

  describe Opal::UI::BarChart do
    it "renders horizontal bars with labels and values in print mode" do
      chart = Opal::UI::BarChart.new
      chart.add("CPU", 80.0, :red)
      chart.add("RAM", 45.0, :green)

      output = chart.to_print_s(width: 50)
      output.should contain("CPU")
      output.should contain("RAM")
      output.should contain("80")
      output.should contain("45")
    end

    it "provides BarChart.to_string helper" do
      items = [{"Alpha", 30.0}, {"Beta", 70.0}]
      output = Opal::UI::BarChart.to_string(items, width: 40)
      output.should contain("Alpha")
      output.should contain("Beta")
    end
  end

  describe Opal::UI::Sparkline do
    it "renders Unicode sparkline blocks in print mode" do
      sparkline = Opal::UI::Sparkline.new([1.0, 3.0, 5.0, 8.0, 4.0, 2.0])
      output = sparkline.to_print_s(width: 40)
      output.should_not be_empty
      output.lines.size.should eq(1)
    end

    it "provides Sparkline.render_to_string helper" do
      output = Opal::UI::Sparkline.render_to_string([10.0, 20.0, 30.0])
      output.should_not be_empty
    end
  end

  describe Opal::UI::LineGraph do
    it "renders cartesian line graph with axes in print mode" do
      graph = Opal::UI::LineGraph.new(title: "Sensor Readings")
      graph.add_series("Temp", [10.0, 25.0, 18.0, 30.0, 22.0], :blue)

      output = graph.to_print_s(width: 60)
      output.should contain("Sensor Readings")
    end

    it "provides LineGraph.to_string helper" do
      series = [{"Speed", [5.0, 15.0, 25.0]}]
      output = Opal::UI::LineGraph.to_string(series, title: "Velocity", width: 50, height: 10)
      output.should contain("Velocity")
    end
  end

  describe Opal::UI::PieChart do
    it "renders pie chart with legend labels and percentages in print mode" do
      pie = Opal::UI::PieChart.new(title: "Storage")
      pie.add("Used", 75.0, :red)
      pie.add("Free", 25.0, :green)

      output = pie.to_print_s(width: 60)
      output.should contain("Used")
      output.should contain("Free")
      output.should contain("75.0%")
      output.should contain("25.0%")
    end

    it "provides PieChart.to_string helper" do
      slices = [{"Cache", 40.0}, {"Data", 60.0}]
      output = Opal::UI::PieChart.to_string(slices, title: "Memory", width: 50, height: 12)
      output.should contain("Memory")
      output.should contain("Cache")
      output.should contain("Data")
    end
  end

  describe Opal::UI::Tree do
    it "renders tree nodes with connector branches in print mode" do
      root = Opal::UI::TreeNode.new("root")
      src = Opal::UI::TreeNode.new("src")
      src.add(Opal::UI::TreeNode.new("main.cr"))
      src.add(Opal::UI::TreeNode.new("parser.cr"))
      root.add(src)
      root.add(Opal::UI::TreeNode.new("shard.yml"))

      tree = Opal::UI::Tree.new(root)
      output = tree.to_print_s(width: 40)
      output.should contain("root")
      output.should contain("src")
      output.should contain("main.cr")
      output.should contain("parser.cr")
      output.should contain("shard.yml")
    end

    it "provides Tree.to_string helper" do
      nodes = [Opal::UI::TreeNode.new("app.cr")]
      output = Opal::UI::Tree.to_string(nodes, title: "Project Structure", width: 40)
      output.should contain("Project Structure")
      output.should contain("app.cr")
    end
  end

  describe Opal::UI::Box do
    it "renders styled container box with title and border in print mode" do
      label = Opal::UI::Text.new("Action completed successfully!")
      box = Opal::UI::Box.new(label, border: :rounded, title: "Alert Box")

      output = box.to_print_s(width: 50)
      output.should contain("Alert Box")
      output.should contain("Action completed successfully!")
      output.should contain("╭")
      output.should contain("╯")
    end

    it "provides Box.to_string helper" do
      output = Opal::UI::Box.to_string("Notice message", title: "Important", border: :heavy, width: 40)
      output.should contain("Important")
      output.should contain("Notice message")
    end
  end

  describe Opal::UI::Gauge do
    it "renders progress gauge with percentage in print mode" do
      gauge = Opal::UI::Gauge.new(0.65)
      output = gauge.to_print_s(width: 40)
      output.should contain("65%")
    end

    it "provides Gauge.to_string helper" do
      output = Opal::UI::Gauge.to_string(0.85, label: "Memory Usage", width: 50)
      output.should contain("85%")
      output.should contain("Memory Usage")
    end
  end

  describe Opal::UI::Badge do
    it "renders badge tag pill in print mode" do
      badge = Opal::UI::Badge.new("PRODUCTION", bg: :green, fg: :white)
      output = badge.to_print_s
      output.should contain("PRODUCTION")
    end

    it "provides Badge.to_string helper" do
      output = Opal::UI::Badge.to_string("BETA", bg: :yellow)
      output.should contain("BETA")
    end
  end

  describe Opal::UI::Rule do
    it "renders horizontal divider rule with centered text in print mode" do
      rule = Opal::UI::Rule.new(text: "SECTION 1", align: :center)
      output = rule.to_print_s(width: 40)
      output.should contain("SECTION 1")
    end

    it "provides Rule.to_string helper" do
      output = Opal::UI::Rule.to_string(text: "Divider", width: 40)
      output.should contain("Divider")
    end
  end

  describe Opal::UI::CodeView do
    it "renders code lines with line numbers in print mode" do
      code = <<-CRYSTAL
      def hello(name : String)
        puts "Hello, \#{name}!"
      end
      CRYSTAL

      view = Opal::UI::CodeView.new(code, language: "crystal", show_line_numbers: true)
      output = view.to_print_s(width: 60)
      output.should contain("def hello")
      output.should contain("puts")
      output.should contain("1")
    end

    it "provides CodeView.to_string helper" do
      output = Opal::UI::CodeView.to_string("let x = 10;", language: "javascript", width: 40)
      output.should contain("let x = 10;")
    end
  end

  describe Opal::UI::Markdown do
    it "renders Markdown content to styled string" do
      md_text = <<-MD
      # Title Header
      This is a **bold** and *italic* test.
      - Item 1
      - Item 2
      MD

      output = Opal::UI::Markdown.render(md_text, width: 60)
      output.should contain("Title Header")
      output.should contain("bold")
      output.should contain("Item 1")
    end
  end
end
