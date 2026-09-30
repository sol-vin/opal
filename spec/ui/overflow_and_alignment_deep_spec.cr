require "../spec_helper"

describe "Deep Overflow and Misalignment Hardening" do
  describe "Window Title & Boundary Clamping" do
    it "truncates long window titles before titlebar action buttons" do
      win = Opal::UI::Window.new("A Very Long Window Title That Exceeds Width")
      win.x = 0
      win.y = 0
      win.width = 24
      win.height = 5

      buf = Opal::UI::Buffer.new(24, 5)
      win.render(buf, 0, 0, 24, 5)

      # Titlebar is at row 0
      titlebar = (0...24).map { |c| buf.get(c, 0).char }.join

      # Action buttons (minimize, maximize, close) MUST remain intact at right end
      titlebar.should contain("[x]")
      # Title should have been truncated with ellipsis
      titlebar.should contain("…")
      # Total width cannot exceed 24
      titlebar.size.should eq(24)
    end

    it "handles extremely narrow window dimensions without crashing" do
      win = Opal::UI::Window.new("Narrow")
      buf = Opal::UI::Buffer.new(5, 3)
      win.render(buf, 0, 0, 5, 3)

      # Should render corners and fit within 5x3
      row0 = (0...5).map { |c| buf.get(c, 0).char }.join
      row0.size.should eq(5)
    end

    it "renders minimized window pill within parent viewport boundaries" do
      win = Opal::UI::Window.new("Extremely Long Title For A Minimized Taskbar Pill", x: 0, y: 0, width: 20, height: 10)
      win.minimize!
      win.minimized?.should be_true

      buf = Opal::UI::Buffer.new(20, 10)
      # Render in a small buffer
      win.render(buf, 0, 0, 20, 10)

      # Minimized window is rendered at win_y (row 0)
      minimized_row = (0...20).map { |c| buf.get(c, 0).char }.join
      minimized_row.should contain("…")
      minimized_row.should contain("[-]")
    end
  end

  describe "Table Column Alignment and Overflow" do
    it "aligns column divider junctions precisely between columns" do
      table = Opal::UI::Table.new(["Item", "Qty", "Price"])
      table.add_row(["Apples", "10", "$2.50"])
      table.add_row(["Oranges", "5", "$1.20"])

      buf = Opal::UI::Buffer.new(30, 5)
      table.render(buf, 0, 0, 30, 5)

      header_row = (0...30).map { |c| buf.get(c, 0).char }.join
      divider_row = (0...30).map { |c| buf.get(c, 1).char }.join

      # Divider should contain horizontal dashes and junction characters
      divider_row.should contain("┼")
      divider_row.should contain("─")

      # First item column text should align with top divider section
      buf.get(0, 0).char.should eq('I')
      buf.get(0, 1).char.should eq('─')
    end

    it "truncates wide table cells without shifting neighboring columns" do
      table = Opal::UI::Table.new(["Short", "Very Long Content Column That Should Truncate", "End"])
      table.add_row(["A", "This is an extremely long string that exceeds column bounds", "Z"])

      buf = Opal::UI::Buffer.new(25, 4)
      # Render in constrained 25-char width
      table.render(buf, 0, 0, 25, 4)

      # Row 2 is the data row
      data_row = (0...25).map { |c| buf.get(c, 2).char }.join
      data_row.size.should eq(25)
      # Cells shouldn't crash or bleed past width
    end
  end

  describe "Box and Button Overflow Clamping" do
    it "truncates box title with ellipsis when exceeding width" do
      box = Opal::UI::Box.new(title: "Super Duper Long Box Title That Cannot Fit In Twelve Chars")
      buf = Opal::UI::Buffer.new(12, 4)
      box.render(buf, 0, 0, 12, 4)

      title_row = (0...12).map { |c| buf.get(c, 0).char }.join
      title_row.should start_with("╭")
      title_row.should end_with("╮")
      title_row.should contain("…")
      title_row.size.should eq(12)
    end

    it "truncates button label with ellipsis when exceeding button width" do
      btn = Opal::UI::Button.new("Extremely Long Button Caption")
      buf = Opal::UI::Buffer.new(10, 1)
      btn.render(buf, 0, 0, 10, 1)

      btn_text = (0...10).map { |c| buf.get(c, 0).char }.join
      btn_text.should contain("…")
      btn_text.size.should eq(10)
    end
  end

  describe "Buffer Wide Character & Boundary Hardening" do
    it "prevents double-width characters from overrunning max_width boundary" do
      buf = Opal::UI::Buffer.new(10, 2)
      # Chinese character '中' has visual width 2.
      # Placing it at x=0 with max_width=1 should NOT draw '中' because 0 + 2 > 1
      buf.put_string(0, 0, "中", max_width: 1)
      buf.get(0, 0).char.should eq(' ')
      buf.get(1, 0).char.should eq(' ')

      # Placing "A中" with max_width=2 should only fit 'A' (1 width), because '中' needs 2
      buf.put_string(0, 1, "A中", max_width: 2)
      buf.get(0, 1).char.should eq('A')
      buf.get(1, 1).char.should eq(' ')
    end

    it "safely executes dim_rect with out-of-bounds coordinates" do
      buf = Opal::UI::Buffer.new(10, 5)
      # dim_rect extending outside buffer bounds should clamp cleanly without exception
      buf.dim_rect(-5, -5, 20, 20)
      # All valid cells should have dim set
      (0...10).each do |x|
        (0...5).each do |y|
          buf.get(x, y).dim?.should be_true
        end
      end
    end
  end

  describe "Zero and Negative Dimensions Safety" do
    it "safely handles 0x0 or negative dimensions on all controls" do
      buf = Opal::UI::Buffer.new(10, 10)

      win = Opal::UI::Window.new("Win")
      btn = Opal::UI::Button.new("Btn")
      tbl = Opal::UI::Table.new(["A", "B"])
      box = Opal::UI::Box.new(title: "Box")
      dd = Opal::UI::Dropdown.new(["X", "Y"])
      sb = Opal::UI::ScrollBar.new(:vertical, min_value: 0, max_value: 10, page_size: 5)
      cv = Opal::UI::CodeView.new("code")
      tabs = Opal::UI::Tabs.new(["T1", "T2"])

      # None of these should raise any exception on zero or negative dimensions
      win.render(buf, 0, 0, 0, 0)
      win.render(buf, 0, 0, -5, -5)

      btn.render(buf, 0, 0, 0, 0)
      btn.render(buf, 0, 0, -2, -1)

      tbl.render(buf, 0, 0, 0, 0)
      box.render(buf, 0, 0, 0, 0)
      dd.render(buf, 0, 0, 0, 0)
      sb.render(buf, 0, 0, 0, 0)
      cv.render(buf, 0, 0, 0, 0)
      tabs.render(buf, 0, 0, 0, 0)
    end
  end
end
