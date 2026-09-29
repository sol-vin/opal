require "./spec_helper"

describe Opal::UI do
  describe "Cell" do
    it "compares equality based on char and styling" do
      c1 = Opal::UI::Cell.new('A', fg: Opal::Color.red, bold: true)
      c2 = Opal::UI::Cell.new('A', fg: Opal::Color.red, bold: true)
      c3 = Opal::UI::Cell.new('A', fg: Opal::Color.blue, bold: true)
      c4 = Opal::UI::Cell.new('B', fg: Opal::Color.red, bold: true)

      (c1 == c2).should be_true
      (c1 == c3).should be_false
      (c1 == c4).should be_false
    end
  end

  describe "Buffer" do
    it "manages cell grid and bounds checking" do
      buf = Opal::UI::Buffer.new(10, 5)
      buf.width.should eq(10)
      buf.height.should eq(5)

      buf.in_bounds?(0, 0).should be_true
      buf.in_bounds?(9, 4).should be_true
      buf.in_bounds?(10, 5).should be_false

      buf.put_char(2, 2, 'X', bold: true)
      cell = buf.get(2, 2)
      cell.char.should eq('X')
      cell.bold?.should be_true
    end

    it "writes strings with max width clipping" do
      buf = Opal::UI::Buffer.new(10, 2)
      buf.put_string(0, 0, "HelloWorld", max_width: 5)
      buf.get(0, 0).char.should eq('H')
      buf.get(4, 0).char.should eq('o')
      buf.get(5, 0).char.should eq(' ') # Clipped
    end

    it "fills rectangular areas and clones correctly" do
      buf = Opal::UI::Buffer.new(4, 4)
      buf.fill(1, 1, 2, 2, Opal::UI::Cell.new('#'))

      buf.get(0, 0).char.should eq(' ')
      buf.get(1, 1).char.should eq('#')
      buf.get(2, 2).char.should eq('#')
      buf.get(3, 3).char.should eq(' ')

      clone_buf = buf.clone
      clone_buf.get(1, 1).char.should eq('#')
    end
  end

  describe "DiffRenderer" do
    it "emits zero output when rendering identical consecutive frames" do
      driver = create_mock_driver(10, 3)
      renderer = Opal::UI::DiffRenderer.new(driver)

      buf = Opal::UI::Buffer.new(10, 3)
      buf.put_string(0, 0, "Frame 1")

      # First render: writes full buffer
      renderer.render(buf)
      driver.output.should_not be_empty
      driver.clear_output

      # Second render with identical buffer: no ANSI escape sequences or characters written!
      renderer.render(buf)
      driver.output.should be_empty
    end

    it "emits minimal diff sequences when a single cell changes" do
      driver = create_mock_driver(10, 3)
      renderer = Opal::UI::DiffRenderer.new(driver)

      buf1 = Opal::UI::Buffer.new(10, 3)
      buf1.put_string(0, 0, "ABCDEF")
      renderer.render(buf1)
      driver.clear_output

      # Change only cell at (2, 0) from 'C' to 'Z'
      buf2 = buf1.clone
      buf2.put_char(2, 0, 'Z')
      renderer.render(buf2)

      # Should jump to row 1, col 3 and write 'Z'
      driver.output.should contain("\e[1;3H")
      driver.output.should contain("Z")
      driver.output.should_not contain("A")
      driver.output.should_not contain("B")
    end
  end

  describe "Components" do
    it "renders Text component" do
      buf = Opal::UI::Buffer.new(20, 2)
      text = Opal::UI::Text.new("Hello\nWorld", fg: :cyan)
      text.render(buf, 0, 0, 20, 2)

      buf.get(0, 0).char.should eq('H')
      buf.get(0, 1).char.should eq('W')
      buf.get(0, 0).fg.should eq(Opal::Color.cyan)
    end

    it "renders Badge component" do
      buf = Opal::UI::Buffer.new(10, 1)
      badge = Opal::UI::Badge.new("OK", bg: :green, fg: :white)
      badge.render(buf, 0, 0, 10, 1)

      buf.get(0, 0).char.should eq(' ')
      buf.get(1, 0).char.should eq('O')
      buf.get(2, 0).char.should eq('K')
      buf.get(3, 0).char.should eq(' ')
      buf.get(1, 0).bg.should eq(Opal::Color.green)
    end

    it "renders Rule component" do
      buf = Opal::UI::Buffer.new(5, 1)
      rule = Opal::UI::Rule.new('─')
      rule.render(buf, 0, 0, 5, 1)

      (0...5).each do |x|
        buf.get(x, 0).char.should eq('─')
      end
    end

    it "renders Box component with title and border" do
      buf = Opal::UI::Buffer.new(12, 3)
      inner = Opal::UI::Text.new("Hi")
      box = Opal::UI::Box.new(inner, border: :rounded, title: "Test")
      box.render(buf, 0, 0, 12, 3)

      # Corners
      buf.get(0, 0).char.should eq('╭')
      buf.get(11, 0).char.should eq('╮')
      buf.get(0, 2).char.should eq('╰')
      buf.get(11, 2).char.should eq('╯')

      # Title
      buf.get(3, 0).char.should eq('T')
      buf.get(4, 0).char.should eq('e')
      buf.get(5, 0).char.should eq('s')
      buf.get(6, 0).char.should eq('t')

      # Content
      buf.get(1, 1).char.should eq('H')
      buf.get(2, 1).char.should eq('i')
    end

    it "renders Table component with headers and columns" do
      buf = Opal::UI::Buffer.new(30, 4)
      tbl = Opal::UI::Table.new(headers: ["Name", "Role"])
      tbl.row(["Alice", "Admin"])
      tbl.row(["Bob", "User"])
      tbl.render(buf, 0, 0, 30, 4)

      # Check Header
      buf.get(0, 0).char.should eq('N')
      buf.get(8, 0).char.should eq('R')

      # Check divider
      buf.get(0, 1).char.should eq('─')

      # Check rows
      buf.get(0, 2).char.should eq('A')
      buf.get(0, 3).char.should eq('B')
    end

    it "renders Viewport component with scrolling" do
      buf = Opal::UI::Buffer.new(10, 2)
      vp = Opal::UI::Viewport.new("Line1\nLine2\nLine3\nLine4", offset_y: 0, show_scrollbar: false)
      vp.render(buf, 0, 0, 10, 2)
      buf.get(4, 0).char.should eq('1')
      buf.get(4, 1).char.should eq('2')

      # Scroll down
      vp.scroll_down(2)
      buf.clear
      vp.render(buf, 0, 0, 10, 2)
      buf.get(4, 0).char.should eq('3')
      buf.get(4, 1).char.should eq('4')
    end
  end

  describe "Declarative DSL" do
    it "renders full composite UI tree via Opal.render_ui" do
      output = Opal.render_ui(width: 40, height: 10) do |ui|
        ui.box(border: :rounded, title: "Lapis Monitor") do |b|
          b.vstack(spacing: 0) do |v|
            v.hstack(spacing: 1) do |h|
              h.badge "BUILDING", bg: :yellow, fg: :black
              h.text "Godot GDExtension", bold: true
            end
            v.rule
            v.table(headers: ["Target", "Status"]) do |t|
              t.row ["linux.x86_64", "OK"]
              t.row ["windows.x86_64", "COMPILING"]
            end
          end
        end
      end

      output.should contain("╭")
      output.should contain("Lapis Monitor")
      output.should contain("BUILDING")
      output.should contain("Godot GDExtension")
      output.should contain("linux.x86_64")
      output.should contain("windows.x86_64")
      output.should contain("╰")
    end
  end
end
