require "./testing/buffer_assertions"
require "./testing/pilot"
require "./testing/teatest"
require "./testing/frame_recorder"

module Opal
  module Testing
    # Top-level helper module designed to be included in Crystal spec suites.
    module SpecHelper
      include BufferAssertions

      # Creates a new Pilot test harness for an Engine, Screen, or ScreenStack.
      def pilot_for(target : UI::Engine | UI::Screen | UI::ScreenStack, driver : Terminal::MockDriver? = nil) : Pilot
        d = driver || Terminal::MockDriver.new(80, 24)
        case target
        when UI::Engine
          Pilot.new(driver: d, engine: target)
        when UI::Screen
          Pilot.new(driver: d, screen_stack: UI::ScreenStack.new(target))
        when UI::ScreenStack
          Pilot.new(driver: d, screen_stack: target)
        else
          Pilot.new(driver: d)
        end
      end

      # Creates and launches a Bubbletea-inspired TestProgram for a TEA Model.
      def teatest(
        model : TEA::Model,
        width : Int32 = 80,
        height : Int32 = 24,
        alt_screen : Bool = false,
        mouse_enabled : Bool = false,
        diff_render : Bool = false,
      ) : TestProgram
        TestProgram.new(
          model,
          width: width,
          height: height,
          alt_screen: alt_screen,
          mouse_enabled: mouse_enabled,
          diff_render: diff_render,
        )
      end

      # Creates a new FrameRecorder instance.
      def create_frame_recorder : FrameRecorder
        FrameRecorder.new
      end
    end
  end
end
