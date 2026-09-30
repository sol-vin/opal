require "../src/opal"

# Custom interactive control implementing Opal::UI::Control
class VolumeSlider < Opal::UI::Control
  property value : Int32
  property min : Int32
  property max : Int32
  property step : Int32

  def initialize(@value : Int32 = 45, @min : Int32 = 0, @max : Int32 = 100, @step : Int32 = 5)
    super() # Automatically invokes setup_default_inputs
  end

  def setup_default_inputs : Nil
    @default_input_proc = ->(ev : Opal::UI::InputEvent) : Bool {
      case ev
      when Opal::Terminal::KeyEvent
        case ev.name
        when "left", "down"
          @value = Math.max(@min, @value - @step)
          true
        when "right", "up"
          @value = Math.min(@max, @value + @step)
          true
        when "home"
          @value = @min
          true
        when "end"
          @value = @max
          true
        else
          false
        end
      else
        false
      end
    }
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
    return if width <= 0 || height <= 0
    buffer.fill(x, y, width, height, ' ')

    ratio = (@value - @min).to_f / (@max - @min).to_f
    bar_w = Math.max(1, width - 14)
    filled = (ratio * bar_w).round.to_i

    border_fg = focused? ? Opal::Color.cyan : Opal::Color.bright_black
    buffer.put_string(x, y, "Volume: ", fg: Opal::Color.white, bold: focused?)
    buffer.put_char(x + 8, y, '[', fg: border_fg)
    buffer.put_string(x + 9, y, "=" * filled, fg: Opal::Color.green, bold: true)
    buffer.put_char(x + 9 + filled, y, 'O', fg: Opal::Color.yellow, bold: true) if filled < bar_w
    buffer.put_string(x + 9 + filled + (filled < bar_w ? 1 : 0), y, "-" * (bar_w - filled - (filled < bar_w ? 1 : 0)), fg: Opal::Color.bright_black)
    buffer.put_char(x + 9 + bar_w, y, ']', fg: border_fg)
    buffer.put_string(x + 11 + bar_w, y, sprintf("%3d%%", @value), fg: Opal::Color.cyan, bold: focused?)
  end

  def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
    {Math.min(available_w, 40), 1}
  end
end

# 1. Instantiate 4 Controls
# Panel 1: Standard ColorPicker (Default Inputs)
picker_default = Opal::UI::ColorPicker.new(Opal::Color.hex("#89B4FA"))

# Panel 2: Vim ColorPicker (Custom Input Hook)
picker_vim = Opal::UI::ColorPicker.new(Opal::Color.hex("#F38BA8"))
picker_vim.on_input do |ctrl, event|
  if event.is_a?(Opal::Terminal::KeyEvent)
    case event.name
    when "h"
      ctrl.adjust_active(-10)
      true
    when "l"
      ctrl.adjust_active(10)
      true
    when "j"
      ctrl.next_channel
      true
    when "k"
      ctrl.prev_channel
      true
    when "r"
      ctrl.color = Opal::Color.red
      true
    when "g"
      ctrl.color = Opal::Color.green
      true
    when "b"
      ctrl.color = Opal::Color.blue
      true
    else
      false # Gracefully fall back to standard controls (+, -, arrows)
    end
  else
    false
  end
end

# Panel 3: Automated Table (Puppeted from code)
table_puppet = Opal::UI::Table.new(
  headers: ["Job ID", "Task", "Status"],
  rows: [
    ["#101", "Compile Kernel", "Running"],
    ["#102", "Run Spec Suite", "Queued"],
    ["#103", "Package Artifacts", "Pending"],
    ["#104", "Deploy Staging", "Pending"],
  ]
)
table_puppet.puppet do |tbl, event|
  if event.is_a?(Opal::Terminal::KeyEvent) && event.name == "auto_tick"
    cur = tbl.selected_index || 0
    tbl.select((cur + 1) % tbl.rows.size)
    true
  else
    false
  end
end

# Panel 4: Custom VolumeSlider Control
slider = VolumeSlider.new(65)

# 2. Setup Opal UI Engine
engine = Opal::UI::Engine.new([picker_default, picker_vim, table_puppet, slider])
status_msg = "Tab/Shift+Tab: switch focus | Esc: exit"

engine.on_focus_change = ->(old_ctrl : Opal::UI::Control?, new_ctrl : Opal::UI::Control?) {
  # Focus change listener
}

drv = Opal::Terminal.default_driver

# Background fiber simulating puppeting ticks on the table
running = true
spawn do
  while running
    sleep 800.milliseconds
    table_puppet.handle_input(Opal::Terminal::KeyEvent.new("auto_tick"))
  end
end

drv.raw_mode do
  drv.hide_cursor
  loop do
    w, h = drv.size
    buf = Opal::UI::Buffer.new(w, h)

    # Title Bar
    title = "💎 Opal UI Control Hooks & Puppeting Engine Demo"
    buf.put_string(2, 0, title, fg: Opal::Color.cyan, bold: true)
    buf.put_string(2, 1, status_msg, fg: Opal::Color.bright_black)
    buf.put_string(0, 2, "─" * w, fg: Opal::Color.bright_black)

    # 2x2 Grid Layout
    pane_w = (w // 2) - 2
    pane_h = ((h - 4) // 2) - 1

    # Quadrant 1: Default ColorPicker
    c1_fg = picker_default.focused? ? Opal::Color.green : Opal::Color.bright_black
    buf.put_string(2, 3, "┌─ Panel 1: Standard ColorPicker [Default Inputs] #{"─" * Math.max(0, pane_w - 49)}┐", fg: c1_fg)
    picker_default.render(buf, 4, 4, pane_w - 4, pane_h - 2)

    # Quadrant 2: Vim ColorPicker
    c2_fg = picker_vim.focused? ? Opal::Color.green : Opal::Color.bright_black
    buf.put_string(w // 2 + 2, 3, "┌─ Panel 2: Vim ColorPicker [Custom on_input Hook] #{"─" * Math.max(0, pane_w - 51)}┐", fg: c2_fg)
    picker_vim.render(buf, w // 2 + 4, 4, pane_w - 4, pane_h - 2)

    # Quadrant 3: Puppeted Table
    c3_fg = table_puppet.focused? ? Opal::Color.green : Opal::Color.bright_black
    buf.put_string(2, pane_h + 4, "┌─ Panel 3: Puppeted Table [Automated Tick Fiber] #{"─" * Math.max(0, pane_w - 49)}┐", fg: c3_fg)
    table_puppet.render(buf, 4, pane_h + 5, pane_w - 4, pane_h - 2)

    # Quadrant 4: Custom Control (VolumeSlider)
    c4_fg = slider.focused? ? Opal::Color.green : Opal::Color.bright_black
    buf.put_string(w // 2 + 2, pane_h + 4, "┌─ Panel 4: Custom VolumeSlider [setup_default_inputs] #{"─" * Math.max(0, pane_w - 54)}┐", fg: c4_fg)
    slider.render(buf, w // 2 + 4, pane_h + 7, pane_w - 4, 3)

    # Render frame
    drv.write(Opal::Terminal::Screen.move_to(1, 1))
    drv.write(buf.to_s)
    drv.flush

    # Process events
    if ev = drv.read_event
      if ev.is_a?(Opal::Terminal::KeyEvent) && (ev.matches?("escape") || ev.matches?("ctrl+c"))
        break
      end
      engine.handle_input(ev)
    end
  end
ensure
  running = false
  drv.show_cursor
end
