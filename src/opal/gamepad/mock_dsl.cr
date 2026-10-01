require "./types"
require "./xinput"

module Opal
  module Input
    module Gamepad
      # Declarative mock/dummy gamepad input builder for automated testing and recorded sessions
      class MockDSL
        getter driver : Driver

        def initialize(@driver : Driver = Driver.new)
        end

        def press(btn : Button | Symbol) : self
          b = parse_button(btn)
          @driver.dispatch(ButtonPress.new(b))
          self
        end

        def release(btn : Button | Symbol) : self
          b = parse_button(btn)
          @driver.dispatch(ButtonRelease.new(b))
          self
        end

        def click(btn : Button | Symbol) : self
          press(btn)
          release(btn)
          self
        end

        def dpad(direction : Symbol) : self
          btn = case direction
                when :up    then Button::DPadUp
                when :down  then Button::DPadDown
                when :left  then Button::DPadLeft
                when :right then Button::DPadRight
                else             raise ArgumentError.new("Invalid dpad direction: #{direction}")
                end
          click(btn)
        end

        def left_stick(x : Float64, y : Float64) : self
          @driver.dispatch(StickMove.new(Stick::Left, x.clamp(-1.0, 1.0), y.clamp(-1.0, 1.0)))
          self
        end

        def right_stick(x : Float64, y : Float64) : self
          @driver.dispatch(StickMove.new(Stick::Right, x.clamp(-1.0, 1.0), y.clamp(-1.0, 1.0)))
          self
        end

        def trigger(side : Trigger | Symbol, value : Float64) : self
          trig = side.is_a?(Trigger) ? side : (side == :left ? Trigger::Left : Trigger::Right)
          @driver.dispatch(TriggerMove.new(trig, value.clamp(0.0, 1.0)))
          self
        end

        def button_chord(btns : Array(Button | Symbol)) : self
          parsed = btns.map { |b| parse_button(b) }
          parsed.each { |b| @driver.dispatch(ButtonPress.new(b)) }
          parsed.each { |b| @driver.dispatch(ButtonRelease.new(b)) }
          self
        end

        def wait_frames(n : Int32) : self
          n.times { Fiber.yield }
          self
        end

        private def parse_button(btn : Button | Symbol) : Button
          return btn if btn.is_a?(Button)
          case btn
          when :a            then Button::A
          when :b            then Button::B
          when :x            then Button::X
          when :y            then Button::Y
          when :dpad_up      then Button::DPadUp
          when :dpad_down    then Button::DPadDown
          when :dpad_left    then Button::DPadLeft
          when :dpad_right   then Button::DPadRight
          when :lb, :left_bumper   then Button::LB
          when :rb, :right_bumper  then Button::RB
          when :start        then Button::Start
          when :back, :select then Button::Back
          when :guide        then Button::Guide
          when :lthumb, :left_thumb  then Button::LThumb
          when :rthumb, :right_thumb then Button::RThumb
          else
            raise ArgumentError.new("Unknown button symbol: :#{btn}")
          end
        end
      end

      # Top-level helper to execute mock gamepad actions
      def self.mock(driver : Driver = Driver.new, &) : Driver
        dsl = MockDSL.new(driver)
        with dsl yield dsl
        driver
      end
    end
  end
end
