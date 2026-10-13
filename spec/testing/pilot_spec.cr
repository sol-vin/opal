require "../spec_helper"

class MockTestControl < Opal::UI::Control
  property received_keys = [] of String
  property received_chars = [] of Char
  property received_mouse = [] of Opal::Terminal::MouseEvent
  property clicks = 0

  def handle_key(event : Opal::Terminal::KeyEvent) : Bool
    @received_keys << event.name
    if ch = event.char
      @received_chars << ch
    end
    true
  end


  def handle_mouse(event : Opal::Terminal::MouseEvent) : Bool
    @received_mouse << event
    if event.action.press? && event.button.left?
      @clicks += 1
    end
    true
  end

  def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
    {10, 3}
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
  end

end


describe Opal::Testing::Pilot do
  describe "Keystroke puppeting" do
    it "simulates special keys like tab, enter, escape, and ctrl+c" do
      c1 = MockTestControl.new
      c2 = MockTestControl.new
      engine = Opal::UI::Engine.new([c1, c2])
      pilot = Opal::Testing::Pilot.for(engine)

      c1.focused?.should be_true
      c2.focused?.should be_false

      # Pressing tab advances focus to c2
      pilot.press("tab")
      c1.focused?.should be_false
      c2.focused?.should be_true

      # Pressing shift+tab cycles back to c1
      pilot.press("shift+tab")
      c1.focused?.should be_true
      c2.focused?.should be_false

      # Dispatching enter and escape to active control
      pilot.press("enter", "escape", "ctrl+c")
      c1.received_keys.should contain("enter")
      c1.received_keys.should contain("escape")
      c1.received_keys.should contain("ctrl+c")
    end

    it "types entire strings character by character" do
      ctrl = MockTestControl.new
      engine = Opal::UI::Engine.new([ctrl])
      pilot = Opal::Testing::Pilot.for(engine)

      pilot.type("Crystal TUI")
      ctrl.received_chars.should eq(['C', 'r', 'y', 's', 't', 'a', 'l', ' ', 'T', 'U', 'I'])
    end
  end

  describe "Mouse puppeting" do
    it "simulates click with press and release actions" do
      ctrl = MockTestControl.new
      engine = Opal::UI::Engine.new([ctrl])
      pilot = Opal::Testing::Pilot.for(engine)

      pilot.click(10, 5)
      ctrl.received_mouse.size.should eq(2)
      ctrl.received_mouse[0].action.should eq(Opal::Terminal::MouseAction::Press)
      ctrl.received_mouse[1].action.should eq(Opal::Terminal::MouseAction::Release)
      ctrl.clicks.should eq(1)
    end

    it "simulates hover motion and scroll wheel events" do
      ctrl = MockTestControl.new
      engine = Opal::UI::Engine.new([ctrl])
      pilot = Opal::Testing::Pilot.for(engine)

      pilot.hover(15, 20)
      ctrl.received_mouse.last.action.should eq(Opal::Terminal::MouseAction::Motion)
      ctrl.received_mouse.last.x.should eq(15)

      ctrl.received_mouse.last.y.should eq(20)

      pilot.scroll_up(5, 5)
      ctrl.received_mouse.last.button.should eq(Opal::Terminal::MouseButton::WheelUp)

      pilot.scroll_down(5, 5)
      ctrl.received_mouse.last.button.should eq(Opal::Terminal::MouseButton::WheelDown)
    end
  end

  describe "Terminal control and synchronization" do
    it "resizes the terminal dimensions" do
      engine = Opal::UI::Engine.new
      pilot = Opal::Testing::Pilot.for(engine)

      pilot.resize_terminal(120, 45)
      pilot.driver.size.should eq({120, 45})
    end

    it "waits for condition to resolve within timeout" do
      ctrl = MockTestControl.new
      engine = Opal::UI::Engine.new([ctrl])
      pilot = Opal::Testing::Pilot.for(engine)

      counter = 0
      spawn do
        sleep 10.milliseconds
        counter = 42
      end

      pilot.wait_for(timeout: 200.milliseconds) { counter == 42 }
      counter.should eq(42)
    end

    it "raises TimeoutError when condition never resolves" do
      engine = Opal::UI::Engine.new
      pilot = Opal::Testing::Pilot.for(engine)

      expect_raises(Opal::Testing::TimeoutError) do
        pilot.wait_for(timeout: 30.milliseconds) { false }
      end
    end

    it "drains mock driver event queues with wait_for_idle" do
      ctrl = MockTestControl.new
      engine = Opal::UI::Engine.new([ctrl])
      driver = create_mock_driver
      driver.inject_key("a", 'a')
      driver.inject_key("b", 'b')

      pilot = Opal::Testing::Pilot.new(driver: driver, engine: engine)
      driver.event_queue.size.should eq(2)

      pilot.wait_for_idle
      driver.event_queue.should be_empty
      ctrl.received_keys.should eq(["a", "b"])
    end
  end
end
