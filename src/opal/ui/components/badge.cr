require "../element"
require "../../style/color"
require "../../style/visual_width"

module Opal
  module UI
    # Renders a highlighted tag or pill badge with custom foreground and background colors.
    class Badge < Element
      property label : String
      property fg : Color
      property bg : Color
      property? bold : Bool

      def initialize(
        @label : String,
        bg : Color | Symbol | String = :blue,
        fg : Color | Symbol | String = :white,
        @bold : Bool = true,
      )
        @bg = Color.from(bg)
        @fg = Color.from(fg)
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        w = VisualWidth.width(@label) + 2 # 1 space padding on left and right
        {Math.min(w, available_w), 1}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if height <= 0 || width <= 0

        badge_text = " #{@label} "
        buffer.put_string(
          x: x,
          y: y,
          text: badge_text,
          fg: @fg,
          bg: @bg,
          bold: @bold,
          max_width: width
        )
      end
    end
  end
end
