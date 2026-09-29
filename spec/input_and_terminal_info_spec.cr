require "./spec_helper"

describe Opal::Terminal::Info do
  it "queries terminal dimensions and capabilities" do
    driver = create_mock_driver(120, 45)
    info = Opal::Terminal::Info.new(driver)

    info.width.should eq(120)
    info.height.should eq(45)
    info.columns.should eq(120)
    info.rows.should eq(45)
    info.size.should eq({120, 45})

    {% if flag?(:windows) %}
      info.windows?.should be_true
      info.posix?.should be_false
    {% else %}
      info.windows?.should be_false
      info.posix?.should be_true
    {% end %}
  end

  it "executes via block DSL" do
    result = Opal.terminal do |term|
      term.columns
    end
    result.should be > 0
  end
end

describe Opal::Input::KeyMap do
  it "matches exact key bindings" do
    pressed_quit = false
    pressed_submit = false

    keymap = Opal.on_key do |k|
      k.on "ctrl+c", "q" { pressed_quit = true }
      k.on "enter" { pressed_submit = true }
    end

    # Test 'q'
    ev_q = Opal::Terminal::AnsiParser.parse_key("q").not_nil!
    keymap.handle(ev_q).should be_true
    pressed_quit.should be_true

    # Test Enter
    ev_enter = Opal::Terminal::AnsiParser.parse_key("\r").not_nil!
    keymap.handle(ev_enter).should be_true
    pressed_submit.should be_true

    # Test unhandled key
    ev_x = Opal::Terminal::AnsiParser.parse_key("x").not_nil!
    keymap.handle(ev_x).should be_false
  end

  it "dispatches character handler for printable text" do
    chars = [] of Char

    keymap = Opal.on_key do |k|
      k.on_char { |ch| chars << ch }
    end

    ev_a = Opal::Terminal::AnsiParser.parse_key("A").not_nil!
    keymap.handle(ev_a).should be_true
    chars.should eq(['A'])
  end
end

describe Opal::Input::MouseMap do
  it "routes mouse clicks and scroll wheel events" do
    clicked = false
    scrolled = 0

    mouse = Opal.on_mouse do |m|
      m.on_click(:left) { clicked = true }
      m.on_scroll_up { scrolled += 1 }
      m.on_scroll_down { scrolled -= 1 }
    end

    # Left click event
    ev_click = Opal::Terminal::MouseEvent.new(10, 5, Opal::Terminal::MouseButton::Left, Opal::Terminal::MouseAction::Press)
    mouse.handle(ev_click).should be_true
    clicked.should be_true

    # Wheel up event
    ev_wheel = Opal::Terminal::MouseEvent.new(10, 5, Opal::Terminal::MouseButton::WheelUp, Opal::Terminal::MouseAction::Press)
    mouse.handle(ev_wheel).should be_true
    scrolled.should eq(1)
  end

  it "hit-tests bounding box zones" do
    zone_hit = false

    mouse = Opal.on_mouse do |m|
      m.zone(x: 10..20, y: 5..10) do |_ev|
        zone_hit = true
      end
    end

    # Inside zone (15, 7)
    ev_inside = Opal::Terminal::MouseEvent.new(15, 7, Opal::Terminal::MouseButton::Left, Opal::Terminal::MouseAction::Press)
    mouse.handle(ev_inside).should be_true
    zone_hit.should be_true

    # Outside zone (5, 2)
    zone_hit = false
    ev_outside = Opal::Terminal::MouseEvent.new(5, 2, Opal::Terminal::MouseButton::Left, Opal::Terminal::MouseAction::Press)
    mouse.handle(ev_outside).should be_false
    zone_hit.should be_false
  end
end

describe Opal::Input::Autocomplete do
  it "computes prefix matches and ghost text suffix" do
    ac = Opal.autocomplete do |a|
      a.candidates "build", "bind engine", "bind project", "clean", "test"
    end

    # Matches
    ac.matches("bi").should eq(["bind engine", "bind project"])
    ac.matches("cle").should eq(["clean"])

    # Ghost text: query "bi" with best match "bind engine" -> "nd engine"
    ac.ghost_text("bi").should eq("nd engine")
    ac.ghost_text("bui").should eq("ld")
    ac.ghost_text("xyz").should be_nil

    # Full completion
    ac.complete("bi").should eq("bind engine")
  end

  it "supports dynamic suggestion providers" do
    ac = Opal.autocomplete do |a|
      a.provider do |q|
        q.starts_with?("g") ? ["godot_4.2", "godot_4.3"] : [] of String
      end
    end

    ac.matches("go").should eq(["godot_4.2", "godot_4.3"])
    ac.ghost_text("go").should eq("dot_4.2")
  end

  it "supports fuzzy matching mode" do
    ac = Opal.autocomplete do |a|
      a.candidates "package", "scaffold", "publish"
      a.match_mode :fuzzy
    end

    ac.matches("pkg").should eq(["package"])
    ac.matches("scf").should eq(["scaffold"])
  end
end

describe Opal::Input::TextInput do
  it "inserts characters and manages cursor navigation" do
    ti = Opal::Input::TextInput.new(prompt: "> ")
    ti.insert('h')
    ti.insert('i')
    ti.value.should eq("hi")
    ti.cursor_pos.should eq(2)

    ti.move_left
    ti.cursor_pos.should eq(1)

    ti.insert('e')
    ti.value.should eq("hei")

    ti.delete_backward
    ti.value.should eq("hi")
  end

  it "provides ghost text and completes on Tab key" do
    ti = Opal::Input::TextInput.new(prompt: "cmd > ")
    ti.autocomplete do |ac|
      ac.candidates "build", "bind engine", "clean"
    end

    # Type 'b'
    ev_b = Opal::Terminal::AnsiParser.parse_key("b").not_nil!
    ti.handle_key(ev_b)
    ti.value.should eq("b")

    # Ghost text should be "uild" (from "build")
    ti.current_ghost_text.should eq("uild")

    # Hit Tab -> accepts autocomplete!
    ev_tab = Opal::Terminal::AnsiParser.parse_key("\t").not_nil!
    ti.handle_key(ev_tab)
    ti.value.should eq("build")
    ti.current_ghost_text.should be_nil
  end

  it "accepts ghost text when Right Arrow is pressed at line end" do
    ti = Opal::Input::TextInput.new
    ti.autocomplete do |ac|
      ac.candidates "test_suite"
    end

    ti.insert('t')
    ti.insert('e')
    ti.current_ghost_text.should eq("st_suite")

    # Hit Right Arrow
    ev_right = Opal::Terminal::AnsiParser.parse_key("\e[C").not_nil!
    ti.handle_key(ev_right)
    ti.value.should eq("test_suite")
  end

  it "manages input history" do
    ti = Opal::Input::TextInput.new
    ti.insert('f')
    ti.insert('i')
    ti.insert('r')
    ti.insert('s')
    ti.insert('t')

    # Submit first
    ev_enter = Opal::Terminal::AnsiParser.parse_key("\r").not_nil!
    ti.handle_key(ev_enter).should be_true
    ti.history.should eq(["first"])

    # Navigate history up
    ev_up = Opal::Terminal::AnsiParser.parse_key("\e[A").not_nil!
    ti.handle_key(ev_up)
    ti.value.should eq("first")
  end
end
