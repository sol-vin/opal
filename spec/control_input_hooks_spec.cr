require "./spec_helper"

# A sample custom control used to verify the documentation example and Control lifecycle
class TestSlider < Opal::UI::Control
  property value : Int32
  property min : Int32
  property max : Int32
  property step : Int32

  def initialize(@value : Int32 = 50, @min : Int32 = 0, @max : Int32 = 100, @step : Int32 = 5)
    super()
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
    buffer.put_string(x, y, sprintf("[%3d%%]", @value))
  end

  def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
    {Math.min(available_w, 20), 1}
  end
end

describe Opal::UI::InputHookable do
  describe "lifecycle and default inputs" do
    it "initializes with default settings" do
      slider = TestSlider.new
      slider.focused?.should be_false
      slider.custom_inputs?.should be_false
      slider.fallback_to_defaults?.should be_true
      slider.input_hook.should be_nil
      slider.default_input_proc.should_not be_nil
    end

    it "handles default input events" do
      slider = TestSlider.new(50)
      key_right = Opal::Terminal::KeyEvent.new("right")
      slider.handle_input(key_right).should be_true
      slider.value.should eq(55)

      key_left = Opal::Terminal::KeyEvent.new("left")
      slider.handle_input(key_left).should be_true
      slider.value.should eq(50)

      key_home = Opal::Terminal::KeyEvent.new("home")
      slider.handle_input(key_home).should be_true
      slider.value.should eq(0)

      key_end = Opal::Terminal::KeyEvent.new("end")
      slider.handle_input(key_end).should be_true
      slider.value.should eq(100)
    end
  end

  describe "custom input hooks" do
    it "intercepts events when on_input hook returns true" do
      slider = TestSlider.new(50)
      custom_called = false

      slider.on_input do |ctrl, event|
        if event.is_a?(Opal::Terminal::KeyEvent) && event.name == "x"
          ctrl.value = 99
          custom_called = true
          true
        else
          false
        end
      end

      slider.custom_inputs?.should be_true

      # Custom key 'x' handled by hook
      slider.handle_input(Opal::Terminal::KeyEvent.new("x")).should be_true
      custom_called.should be_true
      slider.value.should eq(99)
    end

    it "falls back to default inputs when hook returns false and fallback is enabled" do
      slider = TestSlider.new(50)
      custom_called = false

      slider.on_input do |_ctrl, event|
        if event.is_a?(Opal::Terminal::KeyEvent) && event.name == "z"
          true
        else
          custom_called = true
          false # allow fallback
        end
      end

      # 'right' key is not 'z', so hook returns false, falls back to default handler
      slider.handle_input(Opal::Terminal::KeyEvent.new("right")).should be_true
      custom_called.should be_true
      slider.value.should eq(55)
    end

    it "suppresses default inputs when fallback_to_defaults is disabled" do
      slider = TestSlider.new(50)
      slider.on_input do |_ctrl, _event|
        false # refuses all events
      end
      slider.fallback_to_defaults!(false)

      slider.handle_input(Opal::Terminal::KeyEvent.new("right")).should be_false
      slider.value.should eq(50) # Not modified because default handler was skipped
    end

    it "resets inputs and restores defaults cleanly" do
      slider = TestSlider.new(50)
      slider.on_input { |_ctrl, _event| true }
      slider.fallback_to_defaults!(false)
      slider.custom_inputs?.should be_true

      slider.reset_inputs
      slider.custom_inputs?.should be_false
      slider.fallback_to_defaults?.should be_true
      slider.input_hook.should be_nil

      # Default input should work again
      slider.handle_input(Opal::Terminal::KeyEvent.new("right")).should be_true
      slider.value.should eq(55)
    end
  end

  describe "programmatic code puppeting" do
    it "allows puppeting control state from code" do
      slider = TestSlider.new(10)

      # Attach puppeteer
      slider.puppet do |ctrl, event|
        if event.is_a?(Opal::Terminal::KeyEvent) && event.name == "tick"
          ctrl.value = Math.min(ctrl.max, ctrl.value + 1)
          true
        else
          false
        end
      end

      3.times do
        slider.handle_input(Opal::Terminal::KeyEvent.new("tick"))
      end

      slider.value.should eq(13)
    end
  end
end

describe Opal::UI::Engine do
  it "manages controls and tracks active focus" do
    s1 = TestSlider.new(10)
    s2 = TestSlider.new(20)
    s3 = TestSlider.new(30)

    engine = Opal::UI::Engine.new([s1, s2, s3])
    engine.focused_control.should eq(s1)
    s1.focused?.should be_true
    s2.focused?.should be_false
    s3.focused?.should be_false

    engine.focus_next
    engine.focused_control.should eq(s2)
    s1.focused?.should be_false
    s2.focused?.should be_true

    engine.focus_next
    engine.focused_control.should eq(s3)

    # Wrap around
    engine.focus_next
    engine.focused_control.should eq(s1)

    # Reverse focus
    engine.focus_prev
    engine.focused_control.should eq(s3)
  end

  it "triggers on_focus_change callbacks" do
    s1 = TestSlider.new(10)
    s2 = TestSlider.new(20)
    changes = [] of {Opal::UI::Control?, Opal::UI::Control?}

    engine = Opal::UI::Engine.new([s1, s2])
    engine.on_focus_change = ->(old_c : Opal::UI::Control?, new_c : Opal::UI::Control?) {
      changes << {old_c, new_c}
    }

    engine.focus_next
    changes.size.should eq(1)
    changes.first[0].should eq(s1)
    changes.first[1].should eq(s2)

    engine.blur
    changes.size.should eq(2)
    changes.last[0].should eq(s2)
    changes.last[1].should be_nil
  end

  it "navigates focus via Tab and Shift+Tab key events" do
    s1 = TestSlider.new(10)
    s2 = TestSlider.new(20)
    engine = Opal::UI::Engine.new([s1, s2])

    tab_key = Opal::Terminal::KeyEvent.new("tab")
    engine.handle_key(tab_key).should be_true
    engine.focused_control.should eq(s2)

    shift_tab_key = Opal::Terminal::KeyEvent.new("tab", shift: true)
    engine.handle_key(shift_tab_key).should be_true
    engine.focused_control.should eq(s1)

    backtab_key = Opal::Terminal::KeyEvent.new("backtab")
    engine.handle_key(backtab_key).should be_true
    engine.focused_control.should eq(s2)
  end

  it "routes regular keys to the active focused control" do
    s1 = TestSlider.new(50)
    s2 = TestSlider.new(50)
    engine = Opal::UI::Engine.new([s1, s2])

    engine.send_key("right")
    s1.value.should eq(55)
    s2.value.should eq(50) # Inactive control unchanged

    engine.focus(s2)
    engine.send_key("down")
    s1.value.should eq(55)
    s2.value.should eq(45) # Active control updated
  end

  it "supports puppet_step for direct control mutations" do
    s1 = TestSlider.new(50)
    engine = Opal::UI::Engine.new([s1])

    engine.puppet_step do |ctrl|
      if ctrl.is_a?(TestSlider)
        ctrl.value = 88
      end
    end

    s1.value.should eq(88)
  end
end

describe "Built-in Controls as Control instances" do
  it "allows Table to be focused, puppeted, and receive key events" do
    table = Opal::UI::Table.new(
      headers: ["Item", "Qty"],
      rows: [["Apples", "5"], ["Oranges", "12"], ["Bananas", "8"]]
    )
    table.should be_a(Opal::UI::Control)
    table.selected_index.should be_nil

    # Default key handling
    table.handle_input(Opal::Terminal::KeyEvent.new("down")).should be_true
    table.selected_index.should eq(0)
    table.handle_input(Opal::Terminal::KeyEvent.new("down")).should be_true
    table.selected_index.should eq(1)

    # Custom input hook
    table.on_input do |tbl, ev|
      if ev.is_a?(Opal::Terminal::KeyEvent) && ev.name == "space"
        tbl.select(0)
        true
      else
        false
      end
    end

    table.handle_input(Opal::Terminal::KeyEvent.new("space")).should be_true
    table.selected_index.should eq(0)
  end

  it "allows ColorPicker to be focused, puppeted, and receive custom input hooks" do
    picker = Opal::UI::ColorPicker.new(Opal::Color.hex("#FF0000"))
    picker.should be_a(Opal::UI::Control)

    # Custom hook: 'x' inverts or turns to blue
    picker.on_input do |ctrl, ev|
      if ev.is_a?(Opal::Terminal::KeyEvent) && ev.name == "x"
        ctrl.color = Opal::Color.hex("#0000FF")
        true
      else
        false
      end
    end

    picker.handle_input(Opal::Terminal::KeyEvent.new("x")).should be_true
    picker.r.should eq(0)
    picker.b.should eq(255)

    # Fallback to default '+' key increases active channel
    picker.handle_input(Opal::Terminal::KeyEvent.new("+")).should be_true
  end

  it "allows FilterList to be focused and navigated" do
    fl = Opal::UI::FilterList.new(items: ["apple", "banana", "cherry"])
    fl.should be_a(Opal::UI::Control)

    fl.handle_input(Opal::Terminal::KeyEvent.new("a")).should be_true
    fl.query.should eq("a")
    fl.handle_input(Opal::Terminal::KeyEvent.new("backspace")).should be_true
    fl.query.should eq("")
  end

  it "allows FileDialog to be focused and navigated" do
    fd = Opal::UI::FileDialog.new
    fd.should be_a(Opal::UI::Control)

    fd.handle_input(Opal::Terminal::KeyEvent.new("down")).should be_true
    fd.cursor.should be >= 0
  end
end

describe "Example 13 Patterns (Vim ColorPicker, Automated Table, Multi-Control Engine)" do
  it "verifies Vim ColorPicker custom hook logic from Example 13" do
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
          false
        end
      else
        false
      end
    end

    # Test Vim 'r', 'g', 'b' color shortcuts
    picker_vim.handle_input(Opal::Terminal::KeyEvent.new("g")).should be_true
    picker_vim.color.to_rgb.should eq(Opal::Color.green.to_rgb)

    picker_vim.handle_input(Opal::Terminal::KeyEvent.new("r")).should be_true
    picker_vim.color.to_rgb.should eq(Opal::Color.red.to_rgb)

    # Test Vim channel navigation 'j' / 'k'
    picker_vim.active_channel.should eq(:red)
    picker_vim.handle_input(Opal::Terminal::KeyEvent.new("j")).should be_true
    picker_vim.active_channel.should eq(:green)
    picker_vim.handle_input(Opal::Terminal::KeyEvent.new("k")).should be_true
    picker_vim.active_channel.should eq(:red)

    # Test fallback to default '+'
    orig_r = picker_vim.r
    picker_vim.handle_input(Opal::Terminal::KeyEvent.new("+")).should be_true
    picker_vim.r.should eq(orig_r + 1)
  end

  it "verifies automated Table puppeting with auto_tick from Example 13" do
    table_puppet = Opal::UI::Table.new(
      headers: ["Job ID", "Task", "Status"],
      rows: [
        ["#101", "Compile Kernel", "Running"],
        ["#102", "Run Spec Suite", "Queued"],
        ["#103", "Package Artifacts", "Pending"],
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

    table_puppet.handle_input(Opal::Terminal::KeyEvent.new("auto_tick")).should be_true
    table_puppet.selected_index.should eq(1)

    table_puppet.handle_input(Opal::Terminal::KeyEvent.new("auto_tick")).should be_true
    table_puppet.selected_index.should eq(2)

    # Wraps around
    table_puppet.handle_input(Opal::Terminal::KeyEvent.new("auto_tick")).should be_true
    table_puppet.selected_index.should eq(0)
  end

  it "coordinates 4 controls in Engine matching Example 13" do
    c1 = Opal::UI::ColorPicker.new
    c2 = Opal::UI::ColorPicker.new
    c3 = Opal::UI::Table.new(headers: ["A"], rows: [["1"]])
    c4 = TestSlider.new

    engine = Opal::UI::Engine.new([c1, c2, c3, c4])
    engine.focused_control.should eq(c1)

    # Cycle 4 times
    engine.send_key("tab")
    engine.focused_control.should eq(c2)
    engine.send_key("tab")
    engine.focused_control.should eq(c3)
    engine.send_key("tab")
    engine.focused_control.should eq(c4)
    engine.send_key("tab")
    engine.focused_control.should eq(c1)
  end
end
