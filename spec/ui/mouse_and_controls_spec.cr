require "../spec_helper"

describe "Opal UI Controls & Mouse Support" do
  describe Opal::UI::Checkbox do
    it "initializes unchecked and toggles state" do
      cb = Opal::UI::Checkbox.new("Enable Logging", checked: false)
      cb.checked?.should be_false
      cb.toggle
      cb.checked?.should be_true
    end

    it "invokes on_change callback on toggle" do
      called = false
      last_val = false
      cb = Opal::UI::Checkbox.new("Auto-save") do |val|
        called = true
        last_val = val
      end
      cb.toggle
      called.should be_true
      last_val.should be_true
    end

    it "handles keyboard toggle (space and enter)" do
      cb = Opal::UI::Checkbox.new("Turbo")
      space_key = Opal::Terminal::KeyEvent.new(name: "space", char: ' ')
      cb.handle_key(space_key).should be_true
      cb.checked?.should be_true

      enter_key = Opal::Terminal::KeyEvent.new(name: "enter", char: '\r')
      cb.handle_key(enter_key).should be_true
      cb.checked?.should be_false
    end

    it "handles mouse click within bounds" do
      cb = Opal::UI::Checkbox.new("Feature X")
      buf = Opal::UI::Buffer.new(30, 1)
      cb.render(buf, 5, 2, 20, 1)

      # Click inside rendered area
      ev = Opal::Terminal::MouseEvent.new(
        action: Opal::Terminal::MouseAction::Press,
        button: Opal::Terminal::MouseButton::Left,
        x: 6,
        y: 2
      )
      cb.handle_mouse(ev).should be_true
      cb.checked?.should be_true

      # Click outside rendered area
      ev_out = Opal::Terminal::MouseEvent.new(
        action: Opal::Terminal::MouseAction::Press,
        button: Opal::Terminal::MouseButton::Left,
        x: 0,
        y: 0
      )
      cb.handle_mouse(ev_out).should be_false
      cb.checked?.should be_true
    end

    it "respects disabled state" do
      cb = Opal::UI::Checkbox.new("Disabled", disabled: true)
      cb.toggle
      cb.checked?.should be_false

      space_key = Opal::Terminal::KeyEvent.new(name: "space")
      cb.handle_key(space_key).should be_false
      cb.checked?.should be_false
    end

    it "renders checked and unchecked glyphs" do
      cb = Opal::UI::Checkbox.new("Setting", checked: false)
      buf = Opal::UI::Buffer.new(20, 1)
      cb.render(buf, 0, 0, 20, 1)
      buf.render_to_string(with_ansi: false).should contain("[ ] Setting")

      cb.toggle
      cb.render(buf, 0, 0, 20, 1)
      buf.render_to_string(with_ansi: false).should contain("[x] Setting")
    end
  end

  describe Opal::UI::Slider do
    it "clamps value to min and max" do
      slider = Opal::UI::Slider.new(value: 50.0, min: 0.0, max: 100.0, step: 5.0)
      slider.value.should eq(50.0)

      slider.value = 150.0
      slider.value.should eq(100.0)

      slider.value = -10.0
      slider.value.should eq(0.0)
    end

    it "handles keyboard increment and decrement" do
      slider = Opal::UI::Slider.new(value: 20.0, min: 0.0, max: 100.0, step: 5.0)
      right_key = Opal::Terminal::KeyEvent.new(name: "right")
      slider.handle_key(right_key).should be_true
      slider.value.should eq(25.0)

      left_key = Opal::Terminal::KeyEvent.new(name: "left")
      slider.handle_key(left_key).should be_true
      slider.value.should eq(20.0)

      home_key = Opal::Terminal::KeyEvent.new(name: "home")
      slider.handle_key(home_key).should be_true
      slider.value.should eq(0.0)

      end_key = Opal::Terminal::KeyEvent.new(name: "end")
      slider.handle_key(end_key).should be_true
      slider.value.should eq(100.0)
    end

    it "handles mouse wheel scrolling" do
      slider = Opal::UI::Slider.new(value: 50.0, min: 0.0, max: 100.0, step: 10.0)
      up_ev = Opal::Terminal::MouseEvent.new(
        action: Opal::Terminal::MouseAction::Press,
        button: Opal::Terminal::MouseButton::WheelUp,
        x: 0,
        y: 0
      )
      slider.handle_mouse(up_ev).should be_true
      slider.value.should eq(60.0)

      down_ev = Opal::Terminal::MouseEvent.new(
        action: Opal::Terminal::MouseAction::Press,
        button: Opal::Terminal::MouseButton::WheelDown,
        x: 0,
        y: 0
      )
      slider.handle_mouse(down_ev).should be_true
      slider.value.should eq(50.0)
    end

    it "handles mouse click / drag on track proportionally" do
      slider = Opal::UI::Slider.new(value: 0.0, min: 0.0, max: 100.0, step: 1.0)
      buf = Opal::UI::Buffer.new(30, 1)
      # Render at (0, 0) with width 30
      slider.render(buf, 0, 0, 30, 1)

      # Click around the middle of track
      click_ev = Opal::Terminal::MouseEvent.new(
        action: Opal::Terminal::MouseAction::Press,
        button: Opal::Terminal::MouseButton::Left,
        x: 12,
        y: 0
      )
      slider.handle_mouse(click_ev).should be_true
      slider.value.should be > 20.0
      slider.value.should be < 80.0
    end
  end

  describe Opal::UI::CommandPalette do
    it "handles keyboard navigation and filter" do
      pal = Opal::UI::CommandPalette.new
      pal.add("file.new", "New File", "File", "Ctrl+N")
      pal.add("file.open", "Open File", "File", "Ctrl+O")
      pal.add("edit.copy", "Copy", "Edit", "Ctrl+C")

      pal.query = "open"
      pal.matches.size.should eq(1)
      pal.selected_action.not_nil!.id.should eq("file.open")

      pal.query = ""
      pal.cursor = 0
      pal.handle_key(Opal::Terminal::KeyEvent.new(name: "down")).should be_true
      pal.cursor.should eq(1)
    end

    it "handles mouse click to select and execute action" do
      executed = false
      pal = Opal::UI::CommandPalette.new
      pal.add("action.run", "Run Task") { executed = true }

      buf = Opal::UI::Buffer.new(80, 24)
      pal.render(buf, 0, 0, 80, 24)

      # Click on the first row (pal_y = 2, list begins at pal_y + 3 = 5)
      row_y = 5
      click_ev = Opal::Terminal::MouseEvent.new(
        action: Opal::Terminal::MouseAction::Press,
        button: Opal::Terminal::MouseButton::Left,
        x: 40,
        y: row_y
      )
      # Click on current item executes it
      pal.handle_mouse(click_ev).should be_true
      executed.should be_true
    end
  end

  describe Opal::UI::Modal do
    it "navigates buttons with keyboard and submits" do
      submitted_btn = -1
      modal = Opal::UI::Modal.new("Confirm", "Are you sure?", buttons: ["Cancel", "OK"]) do |btn|
        submitted_btn = btn
      end

      modal.selected_button.should eq(0)
      modal.handle_key(Opal::Terminal::KeyEvent.new(name: "right")).should be_true
      modal.selected_button.should eq(1)

      modal.handle_key(Opal::Terminal::KeyEvent.new(name: "enter")).should be_true
      submitted_btn.should eq(1)
    end

    it "handles mouse click on buttons" do
      submitted_btn = -1
      modal = Opal::UI::Modal.new("Notice", "Operation completed", buttons: ["Dismiss"]) do |btn|
        submitted_btn = btn
      end

      buf = Opal::UI::Buffer.new(80, 24)
      modal.render(buf, 0, 0, 80, 24)

      # Button is rendered at modal_y + modal_h - 2, modal_x + 3
      pw, ph = modal.preferred_size(80, 24)
      mx = (80 - pw) // 2
      my = (24 - ph) // 2
      btn_x = mx + 4
      btn_y = my + ph - 2

      click_ev = Opal::Terminal::MouseEvent.new(
        action: Opal::Terminal::MouseAction::Press,
        button: Opal::Terminal::MouseButton::Left,
        x: btn_x,
        y: btn_y
      )
      modal.handle_mouse(click_ev).should be_true
      submitted_btn.should eq(0)
    end
  end

  describe Opal::UI::Tree do
    it "toggles node expansion with keyboard and mouse" do
      tree = Opal::UI::Tree.new(title: "Project Tree")
      root = tree.add("src")
      c1 = root.add("main.cr")
      c2 = root.add("utils.cr")

      root.expanded?.should be_true

      buf = Opal::UI::Buffer.new(40, 10)
      tree.render(buf, 0, 0, 40, 10)

      # Select root and toggle
      tree.selected_node = root
      tree.handle_key(Opal::Terminal::KeyEvent.new(name: "space")).should be_true
      root.expanded?.should be_false

      # Re-render collapsed
      buf.clear
      tree.render(buf, 0, 0, 40, 10)
      buf.render_to_string(with_ansi: false).should_not contain("main.cr")

      # Mouse click to expand again
      click_ev = Opal::Terminal::MouseEvent.new(
        action: Opal::Terminal::MouseAction::Press,
        button: Opal::Terminal::MouseButton::Left,
        x: 2,
        y: 2 # root row after title and underline
      )
      tree.handle_mouse(click_ev).should be_true
      root.expanded?.should be_true
    end
  end

  describe Opal::UI::CodeView do
    it "handles mouse wheel scrolling and click line highlighting" do
      code = (1..20).map { |i| "line #{i} code" }.join("\n")
      cv = Opal::UI::CodeView.new(code: code)
      buf = Opal::UI::Buffer.new(40, 10)
      cv.render(buf, 0, 0, 40, 10)

      # Scroll down
      scroll_ev = Opal::Terminal::MouseEvent.new(
        action: Opal::Terminal::MouseAction::Press,
        button: Opal::Terminal::MouseButton::WheelDown,
        x: 5,
        y: 5
      )
      cv.handle_mouse(scroll_ev).should be_true
      cv.scroll_offset.should eq(2)

      # Click on row 3 to highlight line
      click_ev = Opal::Terminal::MouseEvent.new(
        action: Opal::Terminal::MouseAction::Press,
        button: Opal::Terminal::MouseButton::Left,
        x: 5,
        y: 3
      )
      cv.handle_mouse(click_ev).should be_true
      cv.highlighted_line.should eq(1 + 2 + 3) # start_line(1) + scroll_offset(2) + clicked_row(3) = 6
    end
  end

  describe Opal::UI::HexViewer do
    it "handles mouse click on hex bytes to select byte" do
      data = Bytes[0xDE, 0xAD, 0xBE, 0xEF, 0x01, 0x02, 0x03, 0x04]
      hv = Opal::UI::HexViewer.new(data, bytes_per_row: 4)
      buf = Opal::UI::Buffer.new(50, 5)
      hv.render(buf, 0, 0, 50, 5)

      # Click on second byte (row 0, col 1)
      # addr_w = 12, each byte is 3 chars: col 1 is around x = 12 + 3 = 15
      click_ev = Opal::Terminal::MouseEvent.new(
        action: Opal::Terminal::MouseAction::Press,
        button: Opal::Terminal::MouseButton::Left,
        x: 15,
        y: 0
      )
      hv.handle_mouse(click_ev).should be_true
      hv.selected_byte.should eq(1)
    end
  end
end
