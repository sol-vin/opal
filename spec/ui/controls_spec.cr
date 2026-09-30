require "../spec_helper"

describe "Opal::UI Controls (Button, Dropdown, ScrollBar, Window)" do
  describe "Button" do
    it "fires on_click callback on click" do
      clicked = false
      btn = Opal::UI::Button.new("Submit") { clicked = true }
      btn.click
      clicked.should be_true
    end

    it "handles Enter and Space keys to activate" do
      count = 0
      btn = Opal::UI::Button.new("Save") { count += 1 }
      btn.focused = true

      key_enter = Opal::Terminal::KeyEvent.new("enter", '\r')
      btn.handle_input(key_enter).should be_true
      count.should eq(1)

      key_space = Opal::Terminal::KeyEvent.new("space", ' ')
      btn.handle_input(key_space).should be_true
      count.should eq(2)
    end

    it "handles shortcut character" do
      clicked = false
      btn = Opal::UI::Button.new("Quit", shortcut_char: 'q') { clicked = true }
      btn.handle_input(Opal::Terminal::KeyEvent.new("q", 'q')).should be_true
      clicked.should be_true
    end

    it "toggles active state when toggle: true" do
      btn = Opal::UI::Button.new("Mute", toggle: true)
      btn.active?.should be_false
      btn.click
      btn.active?.should be_true
      btn.click
      btn.active?.should be_false
    end

    it "does not activate when disabled" do
      clicked = false
      btn = Opal::UI::Button.new("Disabled", disabled: true) { clicked = true }
      btn.click
      clicked.should be_false
    end

    it "calculates preferred size based on label and icon" do
      btn = Opal::UI::Button.new("OK", icon: "*")
      w, h = btn.preferred_size(50, 10)
      w.should eq(8) # "[ * OK ]" = 8 chars
      h.should eq(1)
    end
  end

  describe "Dropdown" do
    it "initializes with selected item and closed state" do
      dd = Opal::UI::Dropdown.new(["Ruby", "Crystal", "Rust"], selected_index: 1)
      dd.selected_item.should eq("Crystal")
      dd.expanded?.should be_false
    end

    it "toggles open and closed on Enter or Space" do
      dd = Opal::UI::Dropdown.new(["Option A", "Option B"])
      dd.handle_input(Opal::Terminal::KeyEvent.new("enter")).should be_true
      dd.expanded?.should be_true

      dd.handle_input(Opal::Terminal::KeyEvent.new("escape")).should be_true
      dd.expanded?.should be_false
    end

    it "navigates items with Up and Down arrows while expanded" do
      selected = ""
      dd = Opal::UI::Dropdown.new(["A", "B", "C"], selected_index: 0) do |idx, label|
        selected = label
      end
      dd.open

      dd.handle_input(Opal::Terminal::KeyEvent.new("down")).should be_true
      dd.selected_index.should eq(1)
      selected.should eq("B")

      dd.handle_input(Opal::Terminal::KeyEvent.new("down")).should be_true
      dd.selected_index.should eq(2)
      selected.should eq("C")

      dd.handle_input(Opal::Terminal::KeyEvent.new("up")).should be_true
      dd.selected_index.should eq(1)
      selected.should eq("B")
    end

    it "renders and automatically flips upwards near bottom edge" do
      buf = Opal::UI::Buffer.new(30, 10)
      dd = Opal::UI::Dropdown.new(["One", "Two", "Three", "Four"], selected_index: 0, expanded: true)

      # Render at row 8 (only 2 rows below, popup needs 6 rows -> flips UP)
      dd.render(buf, 2, 8, 20, 1)

      # Header chevron should be '▲'
      buf.get(20, 8).char.should eq('▲')
    end
  end

  describe "ScrollBar" do
    it "clamps value within min_value and max_value" do
      sb = Opal::UI::ScrollBar.new(min_value: 0, max_value: 50, value: 20)
      sb.scroll(40)
      sb.value.should eq(50)

      sb.scroll(-100)
      sb.value.should eq(0)
    end

    it "handles arrow keys and page up/down" do
      sb = Opal::UI::ScrollBar.new(min_value: 0, max_value: 100, value: 50, page_size: 15)

      sb.handle_input(Opal::Terminal::KeyEvent.new("up")).should be_true
      sb.value.should eq(49)

      sb.handle_input(Opal::Terminal::KeyEvent.new("down")).should be_true
      sb.value.should eq(50)

      sb.handle_input(Opal::Terminal::KeyEvent.new("pageup")).should be_true
      sb.value.should eq(35)

      sb.handle_input(Opal::Terminal::KeyEvent.new("pagedown")).should be_true
      sb.value.should eq(50)
    end

    it "renders vertical scrollbar with arrows and proportional thumb" do
      buf = Opal::UI::Buffer.new(5, 12)
      sb = Opal::UI::ScrollBar.new(min_value: 0, max_value: 100, value: 0, page_size: 20)
      sb.render(buf, 2, 1, 1, 10)

      buf.get(2, 1).char.should eq('▲')
      buf.get(2, 10).char.should eq('▼')
      # Thumb at top
      buf.get(2, 2).char.should eq('█')
    end
  end

  describe "Window" do
    it "initializes with dimensions and title" do
      win = Opal::UI::Window.new("Terminal", x: 4, y: 2, width: 30, height: 10)
      win.title.should eq("Terminal")
      win.x.should eq(4)
      win.y.should eq(2)
      win.width.should eq(30)
      win.height.should eq(10)
      win.minimized?.should be_false
      win.maximized?.should be_false
    end

    it "toggles minimize and maximize" do
      win = Opal::UI::Window.new("Editor", x: 5, y: 5, width: 25, height: 10)
      win.toggle_minimize
      win.minimized?.should be_true

      win.toggle_minimize
      win.minimized?.should be_false

      win.toggle_maximize(80, 24)
      win.maximized?.should be_true
      win.x.should eq(0)
      win.y.should eq(0)
      win.width.should eq(80)
      win.height.should eq(24)

      # Restore
      win.toggle_maximize
      win.maximized?.should be_false
      win.x.should eq(5)
      win.y.should eq(5)
      win.width.should eq(25)
      win.height.should eq(10)
    end

    it "renders window with border, title, and client area content" do
      buf = Opal::UI::Buffer.new(40, 15)
      label = Opal::UI::Text.new("Inside Window Content")
      win = Opal::UI::Window.new("App", x: 2, y: 2, width: 30, height: 8, content: label)

      win.render(buf, 0, 0, 40, 15)

      # Title: " App " starting at win_x + 2 = 4
      buf.get(4, 2).char.should eq(' ')
      buf.get(5, 2).char.should eq('A')
      buf.get(6, 2).char.should eq('p')
      buf.get(7, 2).char.should eq('p')

      # Child content inside client area
      buf.get(3, 3).char.should eq('I')
      buf.get(4, 3).char.should eq('n')

      # Close button [x]
      buf.get(28, 2).char.should eq('x')
    end
  end
end
