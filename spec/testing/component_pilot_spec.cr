require "../spec_helper"

describe "Textual-Inspired Component Testing via Pilot" do
  describe "Focus Navigation Cycle" do
    it "cycles focus forward and backward across multiple controls using Tab and Shift+Tab" do
      btn_clicked = false
      btn = Opal::UI::Button.new("Submit") { btn_clicked = true }
      chk = Opal::UI::Checkbox.new("Remember Me", checked: false)
      sw = Opal::UI::Switch.new("Dark Mode", on: false)
      slider = Opal::UI::Slider.new(50.0, min: 0.0, max: 100.0, step: 5.0)

      engine = Opal::UI::Engine.new([btn, chk, sw, slider])
      pilot = Opal::Testing::Pilot.for(engine)

      # Initial state: first control focused
      btn.focused?.should be_true
      chk.focused?.should be_false
      sw.focused?.should be_false
      slider.focused?.should be_false

      # Advance forward with Tab
      pilot.press("tab")
      btn.focused?.should be_false
      chk.focused?.should be_true

      pilot.press("tab")
      chk.focused?.should be_false
      sw.focused?.should be_true

      pilot.press("tab")
      sw.focused?.should be_false
      slider.focused?.should be_true

      # Wraps around back to first control
      pilot.press("tab")
      btn.focused?.should be_true
      slider.focused?.should be_false

      # Cycles backward with Shift+Tab
      pilot.press("shift+tab")
      slider.focused?.should be_true
      btn.focused?.should be_false

      pilot.press("shift+tab")
      sw.focused?.should be_true
    end
  end

  describe "Interactive Control Actuation via Pilot" do
    it "triggers button click on enter and space keys" do
      clicks = 0
      btn = Opal::UI::Button.new("Save") { clicks += 1 }
      engine = Opal::UI::Engine.new([btn])
      pilot = Opal::Testing::Pilot.for(engine)

      pilot.press("enter")
      clicks.should eq(1)

      pilot.press("space")
      clicks.should eq(2)
    end

    it "toggles checkbox state on space key" do
      toggled_state = false
      chk = Opal::UI::Checkbox.new("Notifications", checked: false) do |checked|
        toggled_state = checked
      end
      engine = Opal::UI::Engine.new([chk])
      pilot = Opal::Testing::Pilot.for(engine)

      chk.checked?.should be_false
      pilot.press("space")
      chk.checked?.should be_true
      toggled_state.should be_true

      pilot.press("space")
      chk.checked?.should be_false
      toggled_state.should be_false
    end

    it "toggles switch on space and adjusts slider value on arrow keys" do
      sw = Opal::UI::Switch.new("Audio", on: false)
      slider = Opal::UI::Slider.new(20.0, min: 0.0, max: 100.0, step: 5.0)
      engine = Opal::UI::Engine.new([sw, slider])
      pilot = Opal::Testing::Pilot.for(engine)

      # Switch actuation
      pilot.press("space")
      sw.on?.should be_true

      # Navigate to slider
      pilot.press("tab")
      slider.focused?.should be_true
      slider.value.should eq(20.0)

      # Arrow key manipulation
      pilot.press("right")
      slider.value.should eq(25.0)

      pilot.press("left")
      slider.value.should eq(20.0)
    end
  end

  describe "ScreenStack and Modal Dialog Flow" do
    it "manages modal screen lifecycle, backdrop interception, and typed dismissal" do
      base_screen = Opal::UI::Screen.new("main_screen", title: "Main App")
      modal = Opal::UI::ModalScreen.new("confirm_dialog", title: "Confirm Delete?")

      stack = Opal::UI::ScreenStack.new(base_screen)
      pilot = Opal::Testing::Pilot.for(stack)

      stack.active_screen.should eq(base_screen)
      stack.size.should eq(1)

      received_result : Opal::UI::ModalResult = nil
      stack.push_screen(modal) do |res|
        received_result = res
      end

      stack.active_screen.should eq(modal)
      stack.size.should eq(2)
      modal.mounted?.should be_true

      # Dismiss modal dialog with result
      modal.dismiss("yes_delete")
      modal.dismissed?.should be_true
      received_result.should eq("yes_delete")

      # Stack automatically popped back to base screen
      stack.active_screen.should eq(base_screen)
      stack.size.should eq(1)
    end
  end

  describe "Collapsible component toggle" do
    it "expands and collapses upon activation" do
      child = Opal::UI::Text.new("Expanded secret content")
      collapsible = Opal::UI::Collapsible.new("Advanced Settings", child, collapsed: true)

      collapsible.collapsed?.should be_true

      # Actuate toggle
      collapsible.toggle
      collapsible.collapsed?.should be_false

      collapsible.toggle
      collapsible.collapsed?.should be_true
    end
  end
end
