require "../element"
require "../../style/color"
require "../../style/visual_width"

module Opal
  module UI
    # Renders styled text with optional wrapping or clipping.
    class Text < Element
      property content : String
      property fg : Color
      property bg : Color
      property? bold : Bool
      property? dim : Bool
      property? italic : Bool
      property? underline : Bool
      property? wrap : Bool

      def initialize(
        @content : String,
        fg : Color | Symbol | String = Color.none,
        bg : Color | Symbol | String = Color.none,
        @bold : Bool = false,
        @dim : Bool = false,
        @italic : Bool = false,
        @underline : Bool = false,
        @wrap : Bool = false,
      )
        @fg = Color.from(fg)
        @bg = Color.from(bg)
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        lines = @content.split('\n')
        max_w = lines.map { |l| VisualWidth.width(l) }.max? || 0
        {Math.min(max_w, available_w), Math.min(lines.size, available_h)}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        lines = @content.split('\n')
        cur_y = y

        lines.each do |line|
          break if cur_y >= y + height
          buffer.put_string(
            x: x,
            y: cur_y,
            text: line,
            fg: @fg,
            bg: @bg,
            bold: @bold,
            dim: @dim,
            italic: @italic,
            underline: @underline,
            max_width: width
          )
          cur_y += 1
        end
      end
    end
  end
end
