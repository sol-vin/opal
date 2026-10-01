require "../element"
require "../../style/color"

module Opal
  module UI
    # Horizontal rule divider component with optional title label.
    class Rule < Element
      property char : Char
      property fg : Color
      property text : String?
      property align : Symbol # :left, :center, :right

      def initialize(
        @text : String? = nil,
        char : Char = '─',
        fg : Color | Symbol | String = Color.none,
        @align : Symbol = :center,
      )
        @char = char
        @fg = Color.from(fg)
      end

      def initialize(
        char : Char,
        fg : Color | Symbol | String = Color.none,
        align : Symbol = :center,
      )
        initialize(text: nil, char: char, fg: fg, align: align)
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        {available_w, 1}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if height <= 0 || width <= 0

        if t = @text
          t_w = VisualWidth.width(t)
          if t_w + 4 >= width
            buffer.put_string(x, y, t, fg: @fg, max_width: width)
            return
          end

          case @align
          when :left
            buffer.put_string(x, y, "#{@char} #{t} ", fg: @fg)
            offset = 1 + 1 + t_w + 1
            ((x + offset)...(x + width)).each do |cx|
              buffer.put_char(cx, y, @char, fg: @fg)
            end
          when :right
            offset = width - t_w - 3
            (x...(x + offset)).each do |cx|
              buffer.put_char(cx, y, @char, fg: @fg)
            end
            buffer.put_string(x + offset, y, " #{t} #{@char}", fg: @fg)
          else # :center
            left_w = (width - t_w - 2) // 2
            (x...(x + left_w)).each do |cx|
              buffer.put_char(cx, y, @char, fg: @fg)
            end
            buffer.put_string(x + left_w, y, " #{t} ", fg: @fg)
            right_start = x + left_w + t_w + 2
            (right_start...(x + width)).each do |cx|
              buffer.put_char(cx, y, @char, fg: @fg)
            end
          end
        else
          (x...(x + width)).each do |cur_x|
            buffer.put_char(cur_x, y, @char, fg: @fg)
          end
        end
      end

      # Class convenience method returning styled rule string
      def self.to_string(
        text : String? = nil,
        char : Char = '─',
        fg : Color | Symbol | String = Color.none,
        align : Symbol = :center,
        width : Int32? = nil,
        color : Bool? = nil,
      ) : String
        r = Rule.new(text: text, char: char, fg: fg, align: align)
        r.to_print_s(width: width, color: color)
      end

      # Class convenience method printing styled rule directly to IO
      def self.print(
        text : String? = nil,
        io : IO = STDOUT,
        char : Char = '─',
        fg : Color | Symbol | String = Color.none,
        align : Symbol = :center,
        width : Int32? = nil,
        color : Bool? = nil,
      ) : Nil
        io.puts to_string(text: text, char: char, fg: fg, align: align, width: width, color: color)
      end
    end
  end
end
