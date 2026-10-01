require "../spec_helper"

describe "Textual-Inspired Components" do
  describe Opal::UI::Switch do
    it "initializes with correct on/off state" do
      sw = Opal::UI::Switch.new("Hardware Accel", on: true)
      sw.on?.should be_true
      sw.label.should eq("Hardware Accel")
    end

    it "toggles state and fires on_change callback" do
      toggled_val = nil
      sw = Opal::UI::Switch.new("Sound", on: false) do |val|
        toggled_val = val
      end

      sw.toggle
      sw.on?.should be_true
      toggled_val.should be_true

      sw.toggle
      sw.on?.should be_false
      toggled_val.should be_false
    end

    it "handles keyboard space and enter" do
      sw = Opal::UI::Switch.new("Bluetooth", on: false)
      sw.handle_key(Opal::Terminal::KeyEvent.new("space", ' ')).should be_true
      sw.on?.should be_true

      sw.handle_key(Opal::Terminal::KeyEvent.new("enter", '\r')).should be_true
      sw.on?.should be_false
    end

    it "renders track and pill correctly into buffer" do
      sw = Opal::UI::Switch.new("Turbo", on: true)
      buf = Opal::UI::Buffer.new(30, 3)
      sw.render(buf, 0, 0, 30, 1)

      rendered = buf.render_to_string(with_ansi: false)
      rendered.should contain("[")
      rendered.should contain("]")
      rendered.should contain("Turbo")
    end
  end

  describe Opal::UI::RadioSet do
    it "manages mutually exclusive options" do
      rs = Opal::UI::RadioSet.new(["Dark", "Light", "Solarized"], selected_index: 0)
      rs.selected_index.should eq(0)
      rs.selected_label.should eq("Dark")

      rs.select_index(2)
      rs.selected_index.should eq(2)
      rs.selected_label.should eq("Solarized")
      rs.buttons[0].selected?.should be_false
      rs.buttons[2].selected?.should be_true
    end

    it "navigates with arrow keys" do
      rs = Opal::UI::RadioSet.new(["A", "B", "C"], selected_index: 0)
      rs.handle_key(Opal::Terminal::KeyEvent.new("down")).should be_true
      rs.selected_index.should eq(1)

      rs.handle_key(Opal::Terminal::KeyEvent.new("down")).should be_true
      rs.selected_index.should eq(2)

      rs.handle_key(Opal::Terminal::KeyEvent.new("up")).should be_true
      rs.selected_index.should eq(1)
    end

    it "renders vertical list with radio glyphs" do
      rs = Opal::UI::RadioSet.new(["High", "Medium", "Low"], selected_index: 1)
      buf = Opal::UI::Buffer.new(30, 5)
      rs.render(buf, 0, 0, 30, 3)

      rendered = buf.render_to_string(with_ansi: false)
      rendered.should contain("( ) High")
      rendered.should contain("(●) Medium")
      rendered.should contain("( ) Low")
    end
  end

  describe Opal::UI::Collapsible do
    it "toggles collapsed state and updates chevron" do
      child = Opal::UI::Text.new("Secret content")
      col = Opal::UI::Collapsible.new("Advanced", child: child, collapsed: true)
      col.collapsed?.should be_true

      col.toggle
      col.collapsed?.should be_false

      col.collapse
      col.collapsed?.should be_true

      col.expand
      col.collapsed?.should be_false
    end

    it "hides child when collapsed and renders child when expanded" do
      child = Opal::UI::Text.new("Nested Child Text")
      col = Opal::UI::Collapsible.new("Settings", child: child, collapsed: true)

      buf = Opal::UI::Buffer.new(40, 5)
      col.render(buf, 0, 0, 40, 5)
      rendered = buf.render_to_string(with_ansi: false)
      rendered.should contain("Settings")
      rendered.should_not contain("Nested Child Text")

      buf.clear
      col.expand
      col.render(buf, 0, 0, 40, 5)
      rendered_open = buf.render_to_string(with_ansi: false)
      rendered_open.should contain("Settings")
      rendered_open.should contain("Nested Child Text")
    end
  end

  describe Opal::UI::Digits do
    it "renders block digits without crash" do
      digits = Opal::UI::Digits.new("12:45")
      buf = Opal::UI::Buffer.new(40, 6)
      digits.render(buf, 0, 0, 40, 5)

      rendered = buf.render_to_string(with_ansi: false)
      rendered.should_not be_empty
      rendered.lines.size.should be >= 5
    end

    it "calculates preferred size accurately" do
      digits = Opal::UI::Digits.new("123")
      w, h = digits.preferred_size(80, 24)
      h.should eq(5)
      w.should be > 0
    end
  end

  describe Opal::UI::RichLog do
    it "appends lines and truncates when exceeding max_lines" do
      log = Opal::UI::RichLog.new(max_lines: 5)
      10.times do |i|
        log.write("Log line #{i}")
      end

      log.lines.size.should eq(5)
      log.lines.first.should eq("Log line 5")
      log.lines.last.should eq("Log line 9")
    end

    it "supports manual scrolling and clearing" do
      log = Opal::UI::RichLog.new(max_lines: 20)
      10.times { |i| log.write("Line #{i}") }

      log.scroll_to_top
      log.scroll_offset.should eq(0)

      log.clear
      log.lines.empty?.should be_true
    end
  end

  describe Opal::UI::LoadingIndicator do
    it "advances frames on tick" do
      ind = Opal::UI::LoadingIndicator.new("Loading...", style: :dots)
      ind.frame.should eq(0_u64)
      ind.tick
      ind.frame.should eq(1_u64)

      buf = Opal::UI::Buffer.new(30, 2)
      ind.render(buf, 0, 0, 30, 1)
      rendered = buf.render_to_string(with_ansi: false)
      rendered.should contain("Loading...")
    end
  end

  describe Opal::UI::Header do
    it "renders title and subtitle into top bar" do
      h = Opal::UI::Header.new(title: "Mission Control", subtitle: "Live", show_clock: true)
      buf = Opal::UI::Buffer.new(60, 2)
      h.render(buf, 0, 0, 60, 1)

      rendered = buf.render_to_string(with_ansi: false)
      rendered.should contain("Mission Control")
      rendered.should contain("Live")
    end
  end

  describe Opal::UI::Footer do
    it "renders keyboard binding badges" do
      f = Opal::UI::Footer.new([
        {key: "Q", desc: "Quit"},
        {key: "Tab", desc: "Next"},
      ])
      buf = Opal::UI::Buffer.new(60, 2)
      f.render(buf, 0, 0, 60, 1)

      rendered = buf.render_to_string(with_ansi: false)
      rendered.should contain("Q")
      rendered.should contain("Quit")
      rendered.should contain("Tab")
      rendered.should contain("Next")
    end
  end

  describe Opal::UI::Placeholder do
    it "renders dimensions badge and border" do
      p = Opal::UI::Placeholder.new("Sidebar")
      buf = Opal::UI::Buffer.new(20, 6)
      p.render(buf, 0, 0, 20, 6)

      rendered = buf.render_to_string(with_ansi: false)
      rendered.should contain("Sidebar")
      rendered.should contain("20 × 6")
    end
  end

  describe Opal::UI::ContentSwitcher do
    it "switches active views while keeping states" do
      cs = Opal::UI::ContentSwitcher.new
      t1 = Opal::UI::Text.new("View Alpha")
      t2 = Opal::UI::Text.new("View Beta")

      cs.set_view("alpha", t1)
      cs.set_view("beta", t2)

      cs.active_element.should eq(t1)

      cs.switch_to("beta")
      cs.active_element.should eq(t2)
    end
  end

  describe Opal::UI::DockContainer do
    it "computes layout geometry for top, bottom, left, and center" do
      dc = Opal::UI::DockContainer.new
      header = Opal::UI::Text.new("Header")
      footer = Opal::UI::Text.new("Footer")
      sidebar = Opal::UI::Text.new("Sidebar")
      main = Opal::UI::Text.new("Main")

      dc.dock_top(header, height: 1)
      dc.dock_bottom(footer, height: 1)
      dc.dock_left(sidebar, width: 10)
      dc.dock_center(main)

      layout = dc.compute_layout(0, 0, 80, 24)
      layout.size.should eq(4)

      # Top: x=0, y=0, w=80, h=1
      layout[0][1].should eq(0)
      layout[0][2].should eq(0)
      layout[0][3].should eq(80)
      layout[0][4].should eq(1)

      # Bottom: x=0, y=23, w=80, h=1
      layout[1][1].should eq(0)
      layout[1][2].should eq(23)
      layout[1][3].should eq(80)
      layout[1][4].should eq(1)

      # Left: x=0, y=1, w=10, h=22
      layout[2][1].should eq(0)
      layout[2][2].should eq(1)
      layout[2][3].should eq(10)
      layout[2][4].should eq(22)

      # Center: x=10, y=1, w=70, h=22
      layout[3][1].should eq(10)
      layout[3][2].should eq(1)
      layout[3][3].should eq(70)
      layout[3][4].should eq(22)
    end
  end

  describe Opal::UI::GridContainer do
    it "calculates fractional column widths" do
      gc = Opal::UI::GridContainer.new(
        columns: ["1fr", "2fr", "1fr"],
        gutter_x: 0
      )
      widths = gc.compute_col_widths(80)
      widths.size.should eq(3)
      widths[0].should eq(20)
      widths[1].should eq(40)
      widths[2].should eq(20)
    end
  end

  describe Opal::UI::ScreenStack do
    it "manages push, pop, and modal return callbacks" do
      stack = Opal::UI::ScreenStack.new
      base_screen = Opal::UI::Screen.new("main", "Main Screen")
      stack.push_screen(base_screen)
      stack.size.should eq(1)
      stack.active_screen.should eq(base_screen)

      modal_result = nil
      modal = Opal::UI::ModalScreen.new("confirm", "Confirm")
      stack.push_screen(modal) do |res|
        modal_result = res
      end

      stack.size.should eq(2)
      stack.active_screen.should eq(modal)

      modal.dismiss("confirmed_ok")
      modal_result.should eq("confirmed_ok")
      stack.size.should eq(1)
      stack.active_screen.should eq(base_screen)
    end
  end

  describe Opal::UI::QueryEngine do
    it "locates elements by id, class, and type" do
      root = Opal::UI::VStack.new
      btn = Opal::UI::Button.new("Submit")
      btn.id = "submit-btn"
      btn.add_class("primary-action")

      sw = Opal::UI::Switch.new("Audio", on: true)
      sw.add_class("audio-ctrl")

      root.add(btn)
      root.add(sw)

      # Query by ID
      found_btn = root.query_one?("#submit-btn")
      found_btn.should eq(btn)

      # Query by Class
      found_sw = root.query_one?(".audio-ctrl")
      found_sw.should eq(sw)

      # Query by Type
      all_buttons = root.query(Opal::UI::Button)
      all_buttons.size.should eq(1)
      all_buttons.first.should eq(btn)

      # Query by String Type
      root.query("Switch").size.should eq(1)
    end
  end

  describe Opal::Animation::Animator do
    it "animates values from start to finish with easing" do
      animator = Opal::Animation::Animator.new
      latest_val = 0.0
      completed = false

      start_t = Time.instant
      animator.animate("test_tween", from: 0.0, to: 100.0, duration: 50.milliseconds, now: start_t, on_complete: -> { completed = true }) do |v|
        latest_val = v
      end

      animator.running?.should be_true

      # Middle tick
      animator.tick(start_t + 25.milliseconds)
      latest_val.should be > 0.0
      latest_val.should be < 100.0
      completed.should be_false

      # Finish tick
      animator.tick(start_t + 60.milliseconds)
      latest_val.should eq(100.0)
      completed.should be_true
      animator.running?.should be_false
    end
  end

  describe Opal::Async do
    it "runs background tasks and reports progress" do
      progress_reports = [] of Float64
      worker = Opal::Async.run_worker(name: "calc") do |w|
        w.report_progress(0.5)
        42
      end

      worker.on_progress do |p|
        progress_reports << p
      end

      # Yield to let fiber run
      Fiber.yield
      sleep 10.milliseconds

      worker.state.completed?.should be_true
      worker.result.should eq(42)
    end
  end
end
