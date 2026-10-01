require "../spec_helper"

module Opal::UI
  macro test_overflow_and_bounds(component_name, &builder_block)
    describe "{{component_name.id}} overflow and boundary resilience" do
      it "handles zero-sized buffer rendering without crashing" do
        buf = Buffer.new(10, 10)
        element = begin
          {{builder_block.body}}
        end
        element.render(buf, 0, 0, 0, 0)
        element.render(buf, 0, 0, 0, 10)
        element.render(buf, 0, 0, 10, 0)
      end

      it "handles negative coordinates cleanly" do
        buf = Buffer.new(10, 10)
        element = begin
          {{builder_block.body}}
        end
        element.render(buf, -5, -5, 10, 10)
        element.render(buf, -100, -100, 5, 5)
      end

      it "handles tiny 1x1 constraint rendering" do
        buf = Buffer.new(1, 1)
        element = begin
          {{builder_block.body}}
        end
        element.render(buf, 0, 0, 1, 1)
        buf.to_s.should_not be_nil
      end

      it "handles tight 1-line horizontal strip (80x1)" do
        buf = Buffer.new(80, 1)
        element = begin
          {{builder_block.body}}
        end
        element.render(buf, 0, 0, 80, 1)
      end

      it "handles tight 1-column vertical strip (1x40)" do
        buf = Buffer.new(1, 40)
        element = begin
          {{builder_block.body}}
        end
        element.render(buf, 0, 0, 1, 40)
      end

      it "handles oversized requests beyond buffer dimensions" do
        buf = Buffer.new(10, 5)
        element = begin
          {{builder_block.body}}
        end
        element.render(buf, 0, 0, 100, 100)
      end

      it "computes preferred_size within bounds" do
        element = begin
          {{builder_block.body}}
        end
        w, h = element.preferred_size(0, 0)
        w.should be >= 0
        h.should be >= 0

        w2, h2 = element.preferred_size(5, 5)
        w2.should be >= 0
        h2.should be >= 0
      end
    end
  end

  test_overflow_and_bounds("Text") { Text.new("Hello World\nLine 2") }
  test_overflow_and_bounds("Badge") { Badge.new("NEW", :green) }
  test_overflow_and_bounds("Rule") { Rule.new('─', fg: :cyan) }
  test_overflow_and_bounds("Box") { Box.new(title: "Box", border: :rounded) { text "Inside" } }
  test_overflow_and_bounds("VStack") { VStack.new(spacing: 1) { text "Row 1"; text "Row 2" } }
  test_overflow_and_bounds("HStack") { HStack.new(spacing: 2) { text "Col 1"; text "Col 2" } }
  test_overflow_and_bounds("Table") do
    t = Table.new(["Col A", "Col B"])
    t.row(["Val 1", "Val 2"])
    t
  end
  test_overflow_and_bounds("Viewport") { Viewport.new("Scrollable content\nLine 2\nLine 3") }
  test_overflow_and_bounds("Sparkline") { Sparkline.new([1.0, 5.0, 3.0, 8.0, 2.0]) }
  test_overflow_and_bounds("BarChart") do
    bc = BarChart.new
    bc.add("Item 1", 42.0)
    bc.add("Item 2", 84.0)
    bc
  end
  test_overflow_and_bounds("PieChart") do
    pc = PieChart.new
    pc.add("Slice A", 30.0)
    pc.add("Slice B", 70.0)
    pc
  end
  test_overflow_and_bounds("LineGraph") do
    lg = LineGraph.new
    lg.add_series("S1", [10.0, 20.0, 15.0])
    lg
  end
  test_overflow_and_bounds("Gauge") { Gauge.new(ratio: 0.65, label: "CPU") }
  test_overflow_and_bounds("Tree") do
    root = TreeNode.new("Root")
    root.add("Child 1")
    root.add("Child 2")
    Tree.new(root)
  end
  test_overflow_and_bounds("Modal") { Modal.new(title: "Notice", message: "A modal alert") }
  test_overflow_and_bounds("SplitView") do
    SplitView.new(first: Text.new("Left"), second: Text.new("Right"))
  end
  test_overflow_and_bounds("CodeView") do
    CodeView.new("def hello; puts :world; end", language: :crystal)
  end
  test_overflow_and_bounds("Tabs") { Tabs.from_labels(["Overview", "Logs", "Settings"]) }
  test_overflow_and_bounds("HexViewer") { HexViewer.new("Binary Data Stream".to_slice) }
  test_overflow_and_bounds("FileDialog") { FileDialog.new(initial_path: ".") }
  test_overflow_and_bounds("ColorPicker") { ColorPicker.new(initial_color: Color.hex("#89B4FA")) }
  test_overflow_and_bounds("ColorPicker3D") { ColorPicker3D.new(initial_color: Color.hex("#89B4FA")) }
  test_overflow_and_bounds("Button") { Button.new(label: "Click Me", variant: :primary) }
  test_overflow_and_bounds("Dropdown") { Dropdown.new(items: ["Option 1", "Option 2", "Option 3"]) }
  test_overflow_and_bounds("ScrollBar") { ScrollBar.new(value: 20, max_value: 100) }
  test_overflow_and_bounds("Window") do
    Window.new(title: "App Window", content: Text.new("Window body"))
  end
  test_overflow_and_bounds("Canvas2D") do
    Canvas2D.new(width: 20, height: 10) do |buf, x, y, w, h|
      buf.set(x, y, Cell.new('X'))
    end
  end
  test_overflow_and_bounds("Mesh3D") { Mesh3D.new(shape: :cube) }
  test_overflow_and_bounds("Switch") { Switch.new(label: "Turbo Mode", on: true) }
  test_overflow_and_bounds("Checkbox") { Checkbox.new(label: "Accept terms", checked: true) }
  test_overflow_and_bounds("Slider") { Slider.new(value: 50.0, min: 0.0, max: 100.0) }
  test_overflow_and_bounds("RadioSet") { RadioSet.new(["Alpha", "Beta", "Gamma"]) }
  test_overflow_and_bounds("Collapsible") do
    Collapsible.new(title: "Details", child: Text.new("Hidden details"))
  end
  test_overflow_and_bounds("Digits") { Digits.new("12345") }
  test_overflow_and_bounds("RichLog") do
    rl = RichLog.new
    rl.log("Log entry 1")
    rl.log("Log entry 2")
    rl
  end
  test_overflow_and_bounds("LoadingIndicator") { LoadingIndicator.new(label: "Loading...") }
  test_overflow_and_bounds("Header") { Header.new(title: "Header Title") }
  test_overflow_and_bounds("Footer") { Footer.new }
  test_overflow_and_bounds("Placeholder") { Placeholder.new(label: "Empty Space") }
  test_overflow_and_bounds("Screen") { Screen.new("main_screen", title: "Main Screen") { text "Hello" } }
  test_overflow_and_bounds("ModalScreen") { ModalScreen.new("prompt", title: "Prompt Screen") { text "Confirm" } }
end
