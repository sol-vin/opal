require "../src/opal"

# -------------------------------------------------------------------------
# Opal - Python Textual-Inspired Architecture Demo
# -------------------------------------------------------------------------
# Demonstrates:
#   1. Application Screen Header & Footer with dynamic keyboard caps
#   2. DockContainer layout (:top, :left, :right, :bottom, :center)
#   3. GridContainer with fractional (fr) tracks and spans
#   4. Reactive Controls: Switch, RadioSet, Collapsible accordion
#   5. Visual Widgets: 3x5 block font Digits, LoadingIndicator spinners
#   6. RichLog streaming event viewer with auto-scroll and scrollbar
#   7. DOM Query Engine: element.query("#id"), element.query(Control)
#   8. Opal::Async::Worker background fibers with progress reporting
# -------------------------------------------------------------------------

class TextualDemoApp
  include Opal::TEA::Model

  getter header : Opal::UI::Header
  getter footer : Opal::UI::Footer
  getter switch_sync : Opal::UI::Switch
  getter radio_set : Opal::UI::RadioSet
  getter collapsible : Opal::UI::Collapsible
  getter digits : Opal::UI::Digits
  getter spinner : Opal::UI::LoadingIndicator
  getter rich_log : Opal::UI::RichLog
  getter dock : Opal::UI::DockContainer
  getter root : Opal::UI::Element

  property focus_idx : Int32 = 0
  property tick_count : Int32 = 0

  def initialize
    # 1. Header & Footer
    @header = Opal::UI::Header.new(
      title: "OPAL TEXTUAL WORKSPACE",
      subtitle: "Dock & Screen Engine",
      icon: "[*]",
      show_clock: true
    )

    @footer = Opal::UI::Footer.new
    @footer.add("Tab", "Focus")
    @footer.add("Space", "Toggle")
    @footer.add("1-3", "Environment")
    @footer.add("W", "Spawn Worker")
    @footer.add("Q", "Quit")

    # 2. Reactive Controls
    @switch_sync = Opal::UI::Switch.new(label: "Live Telemetry", on: true)
    @switch_sync.id = "sync-switch"
    @switch_sync.add_class("control")

    @radio_set = Opal::UI::RadioSet.new([
      "Development",
      "Staging",
      "Production",
    ], selected_index: 0)
    @radio_set.id = "env-radios"
    @radio_set.add_class("control")

    child_card = Opal::UI::Text.new("Engine: Opal Pure-Crystal\nStatus: Zero Alloc ANSI\nFibers: Active")
    @collapsible = Opal::UI::Collapsible.new(
      title: "Cluster Telemetry",
      child: child_card,
      collapsed: false
    )
    @collapsible.id = "telemetry-collapse"

    # 3. Digits & Indicators
    @digits = Opal::UI::Digits.new("99.9%", fg: :bright_green)
    @spinner = Opal::UI::LoadingIndicator.new(label: "Async Worker Fiber Active", style: :dots, fg: :bright_cyan)

    # 4. RichLog stream
    @rich_log = Opal::UI::RichLog.new(max_lines: 100)
    @rich_log.id = "app-log"
    @rich_log.write("[00:00:00] Textual engine booted successfully")
    @rich_log.write("[00:00:01] Dock layout mounted: :top, :left, :center, :bottom")
    @rich_log.write("[00:00:02] QueryEngine active: DOM hierarchy indexed")

    # Wire events to log
    @switch_sync.on_change do |on|
      @rich_log.write("[#{Time.local.to_s("%H:%M:%S")}] Telemetry toggle -> #{on ? "ENABLED" : "DISABLED"}")
    end

    @radio_set.on_change do |_idx, label|
      @rich_log.write("[#{Time.local.to_s("%H:%M:%S")}] Active Environment -> #{label}")
    end

    @collapsible.on_toggle do |collapsed|
      @rich_log.write("[#{Time.local.to_s("%H:%M:%S")}] Diagnostics panel -> #{collapsed ? "Closed" : "Opened"}")
    end

    # 5. Build Layout with DockContainer
    @dock = Opal::UI::DockContainer.new
    @dock.dock(@header, :top, size: 1)
    @dock.dock(@footer, :bottom, size: 1)

    # Container root for DOM querying
    @root = @dock

    # Demonstrate DOM Query Engine
    sw = @root.query(Opal::UI::Switch).first?
    log_elem = @root.query_one?("#app-log")
    if sw && log_elem
      @rich_log.write("[00:00:03] DOM Query verification: found ##{sw.id} and ##{log_elem.id}")
    end

    update_focus
  end

  def init : Opal::TEA::Cmd
    schedule_tick
  end

  private def focus_controls : Array(Opal::UI::Control)
    [@switch_sync, @radio_set, @collapsible, @rich_log]
  end

  private def update_focus : Nil
    controls = focus_controls
    controls.each_with_index do |ctrl, idx|
      ctrl.focused = (idx == @focus_idx)
    end
  end

  def spawn_background_task : Nil
    @rich_log.write("[#{Time.local.to_s("%H:%M:%S")}] [Async] Spawning background worker fiber...")
    Opal::Async.run_worker(name: "db_sync") do |worker|
      5.times do |step|
        sleep 50.milliseconds
        worker.report_progress((step + 1) / 5.0)
        @rich_log.write("[#{Time.local.to_s("%H:%M:%S")}] [Worker] Job progress #{((step + 1) * 20)}%")
      end
      @rich_log.write("[#{Time.local.to_s("%H:%M:%S")}] [Worker] Job completed with 0 errors")
      "Worker Finished"
    end
  end

  def update(msg : Opal::TEA::Msg) : {Opal::TEA::Model, Opal::TEA::Cmd}
    case msg
    when Opal::TEA::TickMsg
      @spinner.tick
      @tick_count += 1

      if @switch_sync.on? && @tick_count % 30 == 0
        cpu = 95 + (@tick_count % 5)
        @digits.text = "#{cpu}%"
      end

      {self, schedule_tick}
    when Opal::TEA::KeyMsg
      case msg.key
      when "q", "Q", "esc", "escape"
        {self, Opal::TEA::Cmd.quit}
      when "tab"
        @focus_idx = (@focus_idx + 1) % focus_controls.size
        update_focus
        {self, Opal::TEA::Cmd.redraw}
      when "1"
        @radio_set.select_index(0)
        {self, Opal::TEA::Cmd.redraw}
      when "2"
        @radio_set.select_index(1)
        {self, Opal::TEA::Cmd.redraw}
      when "3"
        @radio_set.select_index(2)
        {self, Opal::TEA::Cmd.redraw}
      when "w", "W"
        spawn_background_task
        {self, Opal::TEA::Cmd.redraw}
      else
        ctrl = focus_controls[@focus_idx]?
        if ctrl
          ev = Opal::Terminal::KeyEvent.new(msg.key, msg.char, msg.ctrl?, msg.alt?, msg.shift?)
          ctrl.handle_key(ev)
        end
        {self, Opal::TEA::Cmd.redraw}
      end
    when Opal::TEA::MouseMsg
      ev = Opal::Terminal::MouseEvent.new(
        x: msg.x,
        y: msg.y,
        button: msg.button,
        action: msg.action,
        ctrl: msg.ctrl?,
        alt: msg.alt?,
        shift: msg.shift?
      )
      @switch_sync.handle_mouse(ev)
      @radio_set.handle_mouse(ev)
      @collapsible.handle_mouse(ev)
      @rich_log.handle_mouse(ev)
      @footer.handle_mouse(ev)
      {self, Opal::TEA::Cmd.redraw}
    else
      {self, Opal::TEA::Cmd.none}
    end
  end

  def render(buffer : Opal::UI::Buffer) : Nil
    cols = buffer.width
    rows = buffer.height
    return if cols < 20 || rows < 8

    buffer.fill(0, 0, cols, rows, ' ')
    theme = Opal::Theme.current

    # Top Header & Bottom Footer
    @header.render(buffer, 0, 0, cols, 1)
    @footer.render(buffer, 0, rows - 1, cols, 1)

    main_y = 1
    main_h = Math.max(0, rows - 2)
    return if main_h < 4

    left_w = Math.min(28, (cols * 0.32).to_i)
    center_w = Math.min(26, (cols * 0.30).to_i)
    right_x = left_w + 1 + center_w + 1
    right_w = Math.max(16, cols - right_x)

    # 1. Left Panel: Controls
    left_box = Opal::UI::Box.new(border: :rounded, title: "Controls", border_fg: theme.border, title_fg: theme.primary)
    left_box.render(buffer, 0, main_y, left_w, main_h)

    cy = main_y + 1
    @switch_sync.render(buffer, 2, cy, left_w - 4, 1)
    cy += 2

    buffer.put_string(2, cy, "─" * Math.max(0, left_w - 4), fg: theme.border)
    cy += 1
    buffer.put_string(2, cy, "Environment Profile:", fg: theme.accent, bold: true)
    cy += 1
    @radio_set.render(buffer, 2, cy, left_w - 4, 3)
    cy += 4

    if cy < main_y + main_h - 2
      buffer.put_string(2, cy, "─" * Math.max(0, left_w - 4), fg: theme.border)
      cy += 1
      rem_h = Math.max(0, (main_y + main_h - 1) - cy)
      @collapsible.render(buffer, 2, cy, left_w - 4, rem_h)
    end

    # 2. Center Panel: Digits & Telemetry
    cen_x = left_w + 1
    cen_box = Opal::UI::Box.new(border: :rounded, title: "Telemetry & Spinnners", border_fg: theme.border, title_fg: theme.accent)
    cen_box.render(buffer, cen_x, main_y, center_w, main_h)

    cen_y = main_y + 1
    buffer.put_string(cen_x + 2, cen_y, "CPU Throughput:", fg: theme.text_muted)
    cen_y += 1
    @digits.render(buffer, cen_x + 2, cen_y, center_w - 4, 5)
    cen_y += 6

    @spinner.render(buffer, cen_x + 2, cen_y, center_w - 4, 1)
    cen_y += 2

    rem_box = Math.max(0, (main_y + main_h - 1) - cen_y)
    if rem_box >= 3
      placeholder = Opal::UI::Placeholder.new("Live Grid", border: :rounded)
      placeholder.render(buffer, cen_x + 2, cen_y, center_w - 4, rem_box)
    end

    # 3. Right Panel: Async RichLog
    right_box = Opal::UI::Box.new(border: :rounded, title: "Async RichLog Stream", border_fg: theme.border, title_fg: theme.success)
    right_box.render(buffer, right_x, main_y, right_w, main_h)
    @rich_log.render(buffer, right_x + 1, main_y + 1, right_w - 2, Math.max(0, main_h - 2))
  end

  def view : String
    cols, rows = Opal::Terminal.default_driver.size
    cols = cols.clamp(70, 140)
    rows = rows.clamp(20, 45)

    buffer = Opal::UI::Buffer.new(cols, rows)
    render(buffer)
    buffer.render_to_string(with_ansi: true)
  end

  private def schedule_tick : Opal::TEA::Cmd
    Opal::TEA::Cmd.tick(50.milliseconds) do |_time|
      Opal::TEA::TickMsg.new
    end
  end
end

if PROGRAM_NAME.includes?("16_textual_architecture")
  puts "Starting Textual Architecture Demo..."
  Opal.run_tea(TextualDemoApp.new, alt_screen: true, diff_render: true)
  puts "Exited cleanly."
end
