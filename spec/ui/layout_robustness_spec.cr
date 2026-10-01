require "../spec_helper"

# A dummy unruly element that intentionally attempts to render outside its assigned boundaries
class RogueElement < Opal::UI::Element
  def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
    {200, 200}
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
    # Intentionally blast characters far outside (x, y, width, height)
    (-10..100).each do |dx|
      (-10..100).each do |dy|
        buffer.put_char(x + dx, y + dy, 'X')
      end
    end
  end
end

describe "Layout Robustness, Scissor Clipping, and Themed Window Drag/Resize" do
  describe "Themed Window Drag and Resize Support" do
    it "handles mouse dragging with position updates and themed drag border" do
      dragged_coords = [] of {Int32, Int32}
      win = Opal::UI::Window.new("Drag Test Window", x: 5, y: 3, width: 30, height: 10)
      win.drag_border_fg = Opal::Color.bright_magenta
      win.on_drag do |_w, nx, ny|
        dragged_coords << {nx, ny}
      end

      buf = Opal::UI::Buffer.new(50, 20)
      win.render(buf, 0, 0, 50, 20)

      # Initially not dragging
      win.dragging?.should be_false

      # Press on titlebar at (7, 3)
      press_event = Opal::Terminal::MouseEvent.new(
        x: 7, y: 3,
        button: Opal::Terminal::MouseButton::Left,
        action: Opal::Terminal::MouseAction::Press
      )
      win.handle_mouse(press_event).should be_true
      win.dragging?.should be_true

      # Drag mouse to (12, 6) -> delta = +5, +3
      drag_event = Opal::Terminal::MouseEvent.new(
        x: 12, y: 6,
        button: Opal::Terminal::MouseButton::Left,
        action: Opal::Terminal::MouseAction::Motion
      )
      win.handle_mouse(drag_event).should be_true
      win.x.should eq(10) # 5 + 5
      win.y.should eq(6)  # 3 + 3
      dragged_coords.should eq([{10, 6}])

      # Render while dragging: verify themed drag border color is applied
      drag_buf = Opal::UI::Buffer.new(50, 20)
      win.render(drag_buf, 0, 0, 50, 20)
      # Window top-left border corner is at (10, 6)
      top_left_cell = drag_buf.get(10, 6)
      top_left_cell.fg.should eq(Opal::Color.bright_magenta)

      # Release mouse
      release_event = Opal::Terminal::MouseEvent.new(
        x: 12, y: 6,
        button: Opal::Terminal::MouseButton::Left,
        action: Opal::Terminal::MouseAction::Release
      )
      win.handle_mouse(release_event).should be_true
      win.dragging?.should be_false
    end

    it "handles mouse resizing with minimum bounds clamping, callbacks, and themed handle" do
      resized_dims = [] of {Int32, Int32}
      win = Opal::UI::Window.new("Resize Test Window", x: 2, y: 2, width: 20, height: 8)
      win.resize_border_fg = Opal::Color.yellow
      win.resize_handle_fg = Opal::Color.bright_cyan
      win.on_resize do |_w, nw, nh|
        resized_dims << {nw, nh}
      end

      # Initial render
      buf = Opal::UI::Buffer.new(50, 20)
      win.render(buf, 0, 0, 50, 20)

      # Press bottom-right corner grip at (x + width - 1, y + height - 1) = (2 + 20 - 1, 2 + 8 - 1) = (21, 9)
      press_event = Opal::Terminal::MouseEvent.new(
        x: 21, y: 9,
        button: Opal::Terminal::MouseButton::Left,
        action: Opal::Terminal::MouseAction::Press
      )
      win.handle_mouse(press_event).should be_true
      win.resizing?.should be_true

      # Drag mouse to (26, 12) -> new_w = 26 - 2 + 1 = 25, new_h = 12 - 2 + 1 = 11
      drag_event = Opal::Terminal::MouseEvent.new(
        x: 26, y: 12,
        button: Opal::Terminal::MouseButton::Left,
        action: Opal::Terminal::MouseAction::Motion
      )
      win.handle_mouse(drag_event).should be_true
      win.width.should eq(25)
      win.height.should eq(11)
      resized_dims.should eq([{25, 11}])

      # Render while resizing: verify resize border color and themed handle glyph
      resize_buf = Opal::UI::Buffer.new(50, 20)
      win.render(resize_buf, 0, 0, 50, 20)
      # Border is at (2, 2)
      border_cell = resize_buf.get(2, 2)
      border_cell.fg.should eq(Opal::Color.yellow)

      # Resize corner grip is at (2 + 25 - 1, 2 + 11 - 1) = (26, 12)
      corner_cell = resize_buf.get(26, 12)
      corner_cell.fg.should eq(Opal::Color.bright_cyan)
      corner_cell.bold?.should be_true

      # Attempt to shrink below minimum size (e.g. min_width: 18, min_height: 5)
      shrink_event = Opal::Terminal::MouseEvent.new(
        x: 5, y: 3,
        button: Opal::Terminal::MouseButton::Left,
        action: Opal::Terminal::MouseAction::Motion
      )
      win.handle_mouse(shrink_event).should be_true
      win.width.should eq(win.min_width)
      win.height.should eq(win.min_height)

      # Release mouse
      release_event = Opal::Terminal::MouseEvent.new(
        x: 5, y: 3,
        button: Opal::Terminal::MouseButton::None,
        action: Opal::Terminal::MouseAction::Release
      )
      win.handle_mouse(release_event).should be_true
      win.resizing?.should be_false
    end

    it "respects relative parent offsets for rendering and mouse hit testing" do
      win = Opal::UI::Window.new("Offset Window", x: 2, y: 2, width: 30, height: 6)
      buf = Opal::UI::Buffer.new(40, 20)

      # Render with container offset (10, 5) -> effective window top-left is (12, 7)
      win.render(buf, 10, 5, 40, 20)

      # Window titlebar is at row 7, starting around column 14 (" Offset Window ")
      buf.get(12, 7).char.should eq('╭')
      buf.get(14, 7).char.should eq(' ')
      buf.get(15, 7).char.should eq('O')

      # Clicking outside effective area (e.g. at local coords 3, 3) fails
      click_miss = Opal::Terminal::MouseEvent.new(
        x: 3, y: 3,
        button: Opal::Terminal::MouseButton::Left,
        action: Opal::Terminal::MouseAction::Press
      )
      win.handle_mouse(click_miss).should be_false

      # Clicking inside effective titlebar at (15, 7) starts drag
      click_hit = Opal::Terminal::MouseEvent.new(
        x: 15, y: 7,
        button: Opal::Terminal::MouseButton::Left,
        action: Opal::Terminal::MouseAction::Press
      )
      win.handle_mouse(click_hit).should be_true
      win.dragging?.should be_true
    end
  end

  describe "Container Scissor Clipping" do
    it "prevents Box child from drawing over borders and drop shadows" do
      box = Opal::UI::Box.new(
        child: RogueElement.new,
        border: :rounded,
        padding: 0
      )
      buf = Opal::UI::Buffer.new(12, 6)
      box.render(buf, 0, 0, 12, 6)

      # Border corners MUST remain intact
      buf.get(0, 0).char.should eq('╭')
      buf.get(11, 0).char.should eq('╮')
      buf.get(0, 5).char.should eq('╰')
      buf.get(11, 5).char.should eq('╯')

      # Side borders MUST remain intact
      (1...5).each do |row|
        buf.get(0, row).char.should eq('│')
        buf.get(11, row).char.should eq('│')
      end

      # Inner child content MUST NOT escape to column 12 or row 6
      buf.get(12, 0).char.should eq(' ')
    end

    it "prevents VStack children from bleeding downward past stack boundary" do
      vstack = Opal::UI::VStack.new(spacing: 0)
      vstack.add(RogueElement.new)
      vstack.add(RogueElement.new)

      buf = Opal::UI::Buffer.new(20, 10)
      # Allocate only 4 vertical rows
      vstack.render(buf, 0, 0, 20, 4)

      # Rows 0..3 may have 'X'
      (0...4).each do |r|
        buf.get(5, r).char.should eq('X')
      end

      # Rows 4..9 MUST remain empty clean spaces
      (4...10).each do |r|
        buf.get(5, r).char.should eq(' ')
      end
    end

    it "prevents HStack children from bleeding rightward past stack boundary" do
      hstack = Opal::UI::HStack.new(spacing: 0)
      hstack.add(RogueElement.new)

      buf = Opal::UI::Buffer.new(20, 10)
      # Allocate only 6 horizontal columns
      hstack.render(buf, 0, 0, 6, 10)

      # Columns 0..5 may have 'X'
      (0...6).each do |c|
        buf.get(c, 2).char.should eq('X')
      end

      # Columns 6..19 MUST remain empty clean spaces
      (6...20).each do |c|
        buf.get(c, 2).char.should eq(' ')
      end
    end

    it "prevents SplitView panes from bleeding across separator" do
      split = Opal::UI::SplitView.horizontal(
        first: RogueElement.new,
        second: Opal::UI::Text.new("Clean"),
        ratio: 0.5,
        separator: '│'
      )
      buf = Opal::UI::Buffer.new(21, 5)
      split.render(buf, 0, 0, 21, 5)

      # Left width = 10, separator at col 10 across all rows
      buf.get(10, 0).char.should eq('│')
      buf.get(10, 2).char.should eq('│')
      # Right pane text renders at (11, 0)
      buf.get(11, 0).char.should eq('C')
      buf.get(12, 0).char.should eq('l')
      # Left rogue element did not bleed into right pane at row 2
      buf.get(11, 2).char.should eq(' ')
    end
  end

  describe "GridContainer Fractional Remainder Distribution" do
    it "distributes remainder fractional pixels evenly without empty trailing columns" do
      # 3 fractional columns of 1fr in 10 pixels with 0 gutter
      grid = Opal::UI::GridContainer.new(
        columns: ["1fr", "1fr", "1fr"],
        rows: ["1fr"],
        gutter_x: 0,
        gutter_y: 0
      )
      widths = grid.compute_col_widths(10)
      # Remainder of 10 / 3 = 3 with remainder 1 -> first column gets 4, others get 3
      widths.should eq([4, 3, 3])
      widths.sum.should eq(10)
    end

    it "handles extreme gutter larger than available container width gracefully" do
      grid = Opal::UI::GridContainer.new(
        columns: ["1fr", "1fr", "1fr"],
        rows: ["1fr"],
        gutter_x: 10,
        gutter_y: 5
      )
      buf = Opal::UI::Buffer.new(5, 5)
      # Total gutter (2 * 10 = 20) exceeds available width 5
      grid.add(Opal::UI::Text.new("TooBig"), 0, 0)
      grid.render(buf, 0, 0, 5, 5)

      # Should clamp safely without exceptions or corrupting buffer
      buf.width.should eq(5)
      buf.height.should eq(5)
    end
  end

  describe "Table Continuous Selection and Divider Alignment" do
    it "renders solid continuous row background across entire row when selected" do
      table = Opal::UI::Table.new(["ID", "Name", "Score"])
      table.add_row(["1", "Alice", "98"])
      table.add_row(["2", "Bob", "85"])
      table.select(0)
      table.selected_bg = Opal::Color.blue

      buf = Opal::UI::Buffer.new(30, 5)
      table.render(buf, 0, 0, 30, 5)

      # Row 2 is the first data row (selected)
      # All cells across width 30 should have blue background
      (0...30).each do |c|
        buf.get(c, 2).bg.should eq(Opal::Color.blue)
      end
    end
  end

  describe "Tabs Windowing and Active Tab Visibility" do
    it "keeps selected active tab visible when total tabs exceed width" do
      items = (1..10).map { |i| "Tab#{i}" }
      tabs = Opal::UI::Tabs.new(items)
      # Select the 9th tab
      tabs.select(8)

      buf = Opal::UI::Buffer.new(25, 2)
      tabs.render(buf, 0, 0, 25, 2)

      rendered = (0...25).map { |c| buf.get(c, 0).char }.join
      # Active tab "Tab9" MUST be present on the rendered line
      rendered.should contain("Tab9")
    end
  end

  describe "HexViewer Column Boundary Scissoring" do
    it "does not bleed past narrow allocated width in split layouts" do
      bytes = Bytes.new(32) { |i| i.to_u8 }
      hex = Opal::UI::HexViewer.new(bytes)

      buf = Opal::UI::Buffer.new(60, 5)
      # Render HexViewer in only 30 columns
      hex.render(buf, 0, 0, 30, 5)

      # Column 29 is within bounds; column 30..59 MUST be completely untouched (' ')
      (30...60).each do |c|
        (0...5).each do |r|
          buf.get(c, r).char.should eq(' ')
        end
      end
    end
  end

  describe "Ultra-Narrow 1x1 and 2x2 Boundary Hardening" do
    it "safely executes all controls within 1x1 buffer without throwing or crashing" do
      buf = Opal::UI::Buffer.new(1, 1)

      controls = [
        Opal::UI::Button.new("OK"),
        Opal::UI::Switch.new("Toggle", on: true),
        Opal::UI::Checkbox.new("Check", checked: true),
        Opal::UI::Slider.new(50.0, 0.0, 100.0),
        Opal::UI::Dropdown.new(["One", "Two"]),
        Opal::UI::Tree.new(title: "MyTree"),
        Opal::UI::CodeView.new("val = 42"),
        Opal::UI::Window.new("Win", x: 0, y: 0, width: 1, height: 1),
        Opal::UI::Modal.new("Title", "Message", ["OK"]),
        Opal::UI::RichLog.new,
        Opal::UI::Sparkline.new([1.0, 2.0, 3.0]),
        Opal::UI::RadioSet.new(["Opt1", "Opt2"]),
      ]

      controls.each do |ctrl|
        ctrl.render(buf, 0, 0, 1, 1)
        buf.get(0, 0).should_not be_nil
      end
    end
  end
end
