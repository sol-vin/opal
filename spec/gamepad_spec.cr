require "./spec_helper"
require "../src/opal/gamepad"

describe "Opal::Input::Gamepad Subsystem & Mock DSL" do
  it "dispatches button events via declarative Mock Gamepad DSL" do
    driver = Opal::Input::Gamepad::Driver.new
    events = [] of Opal::Input::Gamepad::Event
    driver.on_event { |e| events << e }

    Opal.mock_gamepad(driver) do |g|
      g.press :a
      g.release :a
      g.dpad :down
      g.left_stick x: 0.5, y: -0.2
      g.trigger :right, 0.9
    end

    events.size.should eq(6) # press a, release a, press dpad_down, release dpad_down, stick, trigger
    events[0].is_a?(Opal::Input::Gamepad::ButtonPress).should be_true
    events[0].as(Opal::Input::Gamepad::ButtonPress).button.should eq(Opal::Input::Gamepad::Button::A)
    events[1].is_a?(Opal::Input::Gamepad::ButtonRelease).should be_true
    events[2].as(Opal::Input::Gamepad::ButtonPress).button.should eq(Opal::Input::Gamepad::Button::DPadDown)
    events[4].as(Opal::Input::Gamepad::StickMove).x.should eq(0.5)
    events[5].as(Opal::Input::Gamepad::TriggerMove).value.should eq(0.9)
  end

  it "routes gamepad focus navigation through FocusMapper" do
    mapper = Opal::Input::Gamepad::FocusMapper.new
    activated = false
    next_focused = false
    cancelled = false
    prev_slide = false
    next_slide = false

    mapper.on_activate { activated = true }
    mapper.on_next_focus { next_focused = true }
    mapper.on_cancel { cancelled = true }
    mapper.on_prev_slide { prev_slide = true }
    mapper.on_next_slide { next_slide = true }

    mapper.handle(Opal::Input::Gamepad::ButtonPress.new(Opal::Input::Gamepad::Button::DPadDown))
    next_focused.should be_true

    mapper.handle(Opal::Input::Gamepad::ButtonPress.new(Opal::Input::Gamepad::Button::A))
    activated.should be_true

    mapper.handle(Opal::Input::Gamepad::ButtonPress.new(Opal::Input::Gamepad::Button::B))
    cancelled.should be_true

    mapper.handle(Opal::Input::Gamepad::ButtonPress.new(Opal::Input::Gamepad::Button::LB))
    prev_slide.should be_true

    mapper.handle(Opal::Input::Gamepad::ButtonPress.new(Opal::Input::Gamepad::Button::RB))
    next_slide.should be_true
  end

  it "updates and clamps VirtualCursor coordinates" do
    cursor = Opal::Input::Gamepad::VirtualCursor.new(x: 10.0, y: 10.0)
    cursor.speed = 100.0

    # Deflect stick right (x = 1.0, y = 0.0) for 0.1s -> moves +10 in X
    cursor.update(stick_x: 1.0, stick_y: 0.0, max_w: 50, max_h: 20, dt: 0.1)
    cursor.cell_x.should eq(20)
    cursor.cell_y.should eq(10)

    # Clamping against max bounds
    cursor.update(stick_x: 1.0, stick_y: 0.0, max_w: 25, max_h: 20, dt: 1.0)
    cursor.cell_x.should eq(24) # clamped to max_w - 1
  end

  it "supports gamepad_controller DSL in UI builder" do
    builder = Opal::UI::Builder.new
    driver = builder.gamepad_controller(deadzone: 0.2) do |ev|
      # listener
    end
    driver.deadzone.should eq(0.2)
  end
end
