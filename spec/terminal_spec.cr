require "./spec_helper"

describe Opal::Terminal::AnsiParser do
  describe ".parse_key" do
    it "parses enter key" do
      ev = Opal::Terminal::AnsiParser.parse_key("\r")
      ev.should_not be_nil
      ev.not_nil!.name.should eq("enter")
      ev.not_nil!.matches?("enter").should be_true

      ev2 = Opal::Terminal::AnsiParser.parse_key("\n")
      ev2.should_not be_nil
      ev2.not_nil!.name.should eq("enter")
    end

    it "parses tab and backspace keys" do
      tab = Opal::Terminal::AnsiParser.parse_key("\t")
      tab.should_not be_nil
      tab.not_nil!.name.should eq("tab")

      bs = Opal::Terminal::AnsiParser.parse_key("\x7f")
      bs.should_not be_nil
      bs.not_nil!.name.should eq("backspace")
    end

    it "parses escape key" do
      esc = Opal::Terminal::AnsiParser.parse_key("\e")
      esc.should_not be_nil
      esc.not_nil!.name.should eq("escape")
      esc.not_nil!.matches?("esc").should be_true
      esc.not_nil!.matches?("escape").should be_true
    end

    it "parses control key combinations (Ctrl+A..Z, Ctrl+C)" do
      ctrl_c = Opal::Terminal::AnsiParser.parse_key("\x03")
      ctrl_c.should_not be_nil
      ctrl_c.not_nil!.ctrl?.should be_true
      ctrl_c.not_nil!.name.should eq("c")
      ctrl_c.not_nil!.matches?("ctrl+c").should be_true

      ctrl_d = Opal::Terminal::AnsiParser.parse_key("\x04")
      ctrl_d.should_not be_nil
      ctrl_d.not_nil!.ctrl?.should be_true
      ctrl_d.not_nil!.name.should eq("d")
      ctrl_d.not_nil!.matches?("ctrl+d").should be_true
    end

    it "parses arrow keys" do
      up = Opal::Terminal::AnsiParser.parse_key("\e[A")
      up.should_not be_nil
      up.not_nil!.name.should eq("up")
      up.not_nil!.matches?("up").should be_true

      down = Opal::Terminal::AnsiParser.parse_key("\e[B")
      down.should_not be_nil
      down.not_nil!.name.should eq("down")

      right = Opal::Terminal::AnsiParser.parse_key("\e[C")
      right.should_not be_nil
      right.not_nil!.name.should eq("right")

      left = Opal::Terminal::AnsiParser.parse_key("\e[D")
      left.should_not be_nil
      left.not_nil!.name.should eq("left")
    end

    it "parses home, end, page_up, page_down, delete" do
      home = Opal::Terminal::AnsiParser.parse_key("\e[H")
      home.should_not be_nil
      home.not_nil!.name.should eq("home")

      pend = Opal::Terminal::AnsiParser.parse_key("\e[F")
      pend.should_not be_nil
      pend.not_nil!.name.should eq("end")

      pgup = Opal::Terminal::AnsiParser.parse_key("\e[5~")
      pgup.should_not be_nil
      pgup.not_nil!.name.should eq("page_up")

      pgdn = Opal::Terminal::AnsiParser.parse_key("\e[6~")
      pgdn.should_not be_nil
      pgdn.not_nil!.name.should eq("page_down")

      del = Opal::Terminal::AnsiParser.parse_key("\e[3~")
      del.should_not be_nil
      del.not_nil!.name.should eq("delete")
    end

    it "parses function keys F1-F12" do
      f1 = Opal::Terminal::AnsiParser.parse_key("\eOP")
      f1.should_not be_nil
      f1.not_nil!.name.should eq("f1")

      f5 = Opal::Terminal::AnsiParser.parse_key("\e[15~")
      f5.should_not be_nil
      f5.not_nil!.name.should eq("f5")

      f12 = Opal::Terminal::AnsiParser.parse_key("\e[24~")
      f12.should_not be_nil
      f12.not_nil!.name.should eq("f12")
    end

    it "parses modified keys like Ctrl+Up" do
      ctrl_up = Opal::Terminal::AnsiParser.parse_key("\e[1;5A")
      ctrl_up.should_not be_nil
      ctrl_up.not_nil!.name.should eq("up")
      ctrl_up.not_nil!.ctrl?.should be_true
      ctrl_up.not_nil!.matches?("ctrl+up").should be_true
    end

    it "parses regular characters" do
      ev = Opal::Terminal::AnsiParser.parse_key("q")
      ev.should_not be_nil
      ev.not_nil!.name.should eq("q")
      ev.not_nil!.matches?("q").should be_true
    end
  end

  describe ".parse_mouse" do
    it "parses SGR mouse left click press" do
      ev = Opal::Terminal::AnsiParser.parse_mouse("\e[<0;25;10M")
      ev.should_not be_nil
      m = ev.not_nil!
      m.x.should eq(25)
      m.y.should eq(10)
      m.button.should eq(Opal::Terminal::MouseButton::Left)
      m.action.should eq(Opal::Terminal::MouseAction::Press)
    end

    it "parses SGR mouse release" do
      ev = Opal::Terminal::AnsiParser.parse_mouse("\e[<0;25;10m")
      ev.should_not be_nil
      m = ev.not_nil!
      m.action.should eq(Opal::Terminal::MouseAction::Release)
    end

    it "parses scroll wheel events" do
      wheel_up = Opal::Terminal::AnsiParser.parse_mouse("\e[<64;15;5M")
      wheel_up.should_not be_nil
      wheel_up.not_nil!.button.should eq(Opal::Terminal::MouseButton::WheelUp)

      wheel_down = Opal::Terminal::AnsiParser.parse_mouse("\e[<65;15;5M")
      wheel_down.should_not be_nil
      wheel_down.not_nil!.button.should eq(Opal::Terminal::MouseButton::WheelDown)
    end
  end

  describe ".parse_all" do
    it "parses coalesced mouse press and release packets in a single read chunk" do
      events = Opal::Terminal::AnsiParser.parse_all("\e[<0;25;10M\e[<0;25;10m")
      events.size.should eq(2)

      p = events[0].as(Opal::Terminal::MouseEvent)
      p.x.should eq(25)
      p.y.should eq(10)
      p.button.should eq(Opal::Terminal::MouseButton::Left)
      p.action.should eq(Opal::Terminal::MouseAction::Press)

      r = events[1].as(Opal::Terminal::MouseEvent)
      r.x.should eq(25)
      r.y.should eq(10)
      r.button.should eq(Opal::Terminal::MouseButton::Left)
      r.action.should eq(Opal::Terminal::MouseAction::Release)
    end

    it "parses rapid mouse wheel events" do
      events = Opal::Terminal::AnsiParser.parse_all("\e[<64;10;5M\e[<65;10;5M")
      events.size.should eq(2)
      events[0].as(Opal::Terminal::MouseEvent).button.should eq(Opal::Terminal::MouseButton::WheelUp)
      events[1].as(Opal::Terminal::MouseEvent).button.should eq(Opal::Terminal::MouseButton::WheelDown)
    end

    it "parses mixed mouse and keyboard events in a single packet" do
      events = Opal::Terminal::AnsiParser.parse_all("\e[<0;10;5Ma\e[A\e[<0;10;5m")
      events.size.should eq(4)

      events[0].as(Opal::Terminal::MouseEvent).action.should eq(Opal::Terminal::MouseAction::Press)
      events[1].as(Opal::Terminal::KeyEvent).name.should eq("a")
      events[2].as(Opal::Terminal::KeyEvent).name.should eq("up")
      events[3].as(Opal::Terminal::MouseEvent).action.should eq(Opal::Terminal::MouseAction::Release)
    end

    it "parses mouse modifier keys" do
      ctrl_click = Opal::Terminal::AnsiParser.parse_all("\e[<16;12;8M").first.as(Opal::Terminal::MouseEvent)
      ctrl_click.ctrl?.should be_true

      shift_click = Opal::Terminal::AnsiParser.parse_all("\e[<4;12;8M").first.as(Opal::Terminal::MouseEvent)
      shift_click.shift?.should be_true

      alt_click = Opal::Terminal::AnsiParser.parse_all("\e[<8;12;8M").first.as(Opal::Terminal::MouseEvent)
      alt_click.alt?.should be_true
    end

    it "returns empty array for empty input" do
      Opal::Terminal::AnsiParser.parse_all("").should be_empty
    end
  end
end

describe Opal::Terminal::MockDriver do
  it "manages virtual dimensions" do
    driver = create_mock_driver(100, 40)
    driver.size.should eq({100, 40})
  end

  it "tracks raw mode and alternate screen state" do
    driver = create_mock_driver
    driver.in_raw_mode?.should be_false
    driver.alt_screen?.should be_false

    driver.raw_mode do
      driver.in_raw_mode?.should be_true
      driver.enter_alternate_screen
      driver.alt_screen?.should be_true
    end

    driver.in_raw_mode?.should be_false
    driver.exit_alternate_screen
    driver.alt_screen?.should be_false
  end

  it "injects keys and consumes from event queue" do
    driver = create_mock_driver
    driver.inject_key("up")
    driver.inject_key("enter")

    ev1 = driver.read_event.as(Opal::Terminal::KeyEvent)
    ev1.name.should eq("up")

    ev2 = driver.read_event.as(Opal::Terminal::KeyEvent)
    ev2.name.should eq("enter")

    driver.read_event.should be_nil
  end

  it "records output and provides stripped output without ANSI" do
    driver = create_mock_driver
    driver.write("\e[31mHello\e[0m World")
    driver.output.should eq("\e[31mHello\e[0m World")
    driver.stripped_output.should eq("Hello World")
  end
end
