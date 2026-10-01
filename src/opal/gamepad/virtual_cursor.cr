require "../ui/buffer"
require "../style/color"

module Opal
  module Input
    module Gamepad
      # Analog virtual cursor that allows gamepad thumbsticks to navigate and click
      # anywhere across the terminal grid like a mouse cursor.
      class VirtualCursor
        property x : Float64
        property y : Float64
        property speed : Float64 = 30.0 # Characters per second at full deflection
        property cursor_glyph : Char = '┼'
        property cursor_color : Color = Color.hex("#ffea00")
        property? visible : Bool = true

        def initialize(@x : Float64 = 40.0, @y : Float64 = 12.0)
        end

        def cell_x : Int32
          @x.round.to_i
        end

        def cell_y : Int32
          @y.round.to_i
        end

        # Updates virtual cursor coordinates based on stick deflection (-1.0 to 1.0)
        def update(stick_x : Float64, stick_y : Float64, max_w : Int32, max_h : Int32, dt : Float64 = 0.0166) : Nil
          # Y axis is inverted in gamepad thumbsticks (up is positive), but down is positive in terminal grids
          @x += stick_x * @speed * dt
          @y -= stick_y * (@speed * 0.5) * dt # Aspect ratio compensation

          @x = @x.clamp(0.0, Math.max(0, max_w - 1).to_f)
          @y = @y.clamp(0.0, Math.max(0, max_h - 1).to_f)
        end

        # Renders the virtual cursor glyph over the buffer
        def render(buffer : UI::Buffer) : Nil
          return unless @visible
          cx = cell_x
          cy = cell_y
          if buffer.in_bounds?(cx, cy)
            buffer.put_char(cx, cy, @cursor_glyph, fg: @cursor_color, bold: true, reverse: true)
          end
        end
      end
    end
  end
end
