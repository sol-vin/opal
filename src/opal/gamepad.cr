require "./ui"
require "./gamepad/types"
require "./gamepad/xinput"
require "./gamepad/virtual_cursor"
require "./gamepad/focus_mapper"
require "./gamepad/mock_dsl"

module Opal
  module Input
    module Gamepad
      # Public factory to create and listen to gamepad events
      def self.create_driver(user_index : Int32 = 0) : Driver
        Driver.new.tap { |d| d.user_index = user_index }
      end

      # Returns true if a physical gamepad is connected on slot user_index
      def self.connected?(user_index : Int32 = 0) : Bool
        driver = Driver.new.tap { |d| d.user_index = user_index }
        driver.poll
        driver.connected?
      end
    end
  end

  # Top-level helper for declarative mock gamepad testing
  def self.mock_gamepad(driver : Input::Gamepad::Driver = Input::Gamepad::Driver.new, &block : Input::Gamepad::MockDSL -> Nil) : Input::Gamepad::Driver
    Input::Gamepad.mock(driver, &block)
  end

  module UI
    module DSL
      # DSL helper to instantiate and listen to a gamepad controller
      def gamepad_controller(virtual_cursor : Bool = false, deadzone : Float64 = 0.15, &block : Input::Gamepad::Event -> Nil) : Input::Gamepad::Driver
        driver = Input::Gamepad::Driver.new
        driver.deadzone = deadzone
        driver.on_event(&block)
        driver
      end

      # DSL helper to simulate mock gamepad inside UI trees
      def mock_gamepad(driver : Input::Gamepad::Driver = Input::Gamepad::Driver.new, &block : Input::Gamepad::MockDSL -> Nil) : Input::Gamepad::Driver
        Input::Gamepad.mock(driver, &block)
      end
    end
  end
end
