require "../element"
require "../../style/color"

module Opal
  module UI
    # Horizontal rule divider component.
    class Rule < Element
      property char : Char
      property fg : Color

      def initialize(char : Char = '─', fg : Color | Symbol | String = Color.none)
        @char = char
        @fg = Color.from(fg)
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        {available_w, 1}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if height <= 0 || width <= 0
        (x...(x + width)).each do |cur_x|
          buffer.put_char(cur_x, y, @char, fg: @fg)
        end
      end
    end
  end
end
