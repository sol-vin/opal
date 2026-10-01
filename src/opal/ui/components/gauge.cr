require "../element"
require "../buffer"
require "../../style/color"
require "../../style/visual_width"

module Opal
  module UI
    # Progress gauge with percentage indicator and custom fill/empty glyphs.
    class Gauge < Element
      getter ratio : Float64
      getter label : String?
      getter color : Color?
      getter filled_char : Char
      getter empty_char : Char

      def initialize(
        ratio : Float64,
        @label : String? = nil,
        color : Color | Symbol | String | Nil = nil,
        @filled_char : Char = '█',
        @empty_char : Char = '░',
      )
        @ratio = ratio.clamp(0.0, 1.0)
        @color = color ? Color.from(color) : nil
      end

      # Dynamic color based on percentage threshold if no explicit color was set
      def resolved_color : Color
        if c = @color
          return c
        end

        if @ratio < 0.6
          Color.green
        elsif @ratio < 0.85
          Color.yellow
        else
          Color.red
        end
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        {available_w, 1}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 8

        pct_text = sprintf("%3d%%", (@ratio * 100).round.to_i)
        cur_x = x

        # Draw optional label
        if l = @label
          buffer.put_string(cur_x, y, l, fg: Color.white, bold: true)
          cur_x += VisualWidth.width(l) + 1
        end

        bar_w = Math.max(1, (x + width) - cur_x - pct_text.size - 3)
        filled_w = (@ratio * bar_w).round.to_i
        empty_w = bar_w - filled_w

        c = resolved_color

        buffer.put_char(cur_x, y, '[', fg: Color.bright_black)
        cur_x += 1

        if filled_w > 0
          buffer.put_string(cur_x, y, @filled_char.to_s * filled_w, fg: c)
          cur_x += filled_w
        end

        if empty_w > 0
          buffer.put_string(cur_x, y, @empty_char.to_s * empty_w, fg: Color.bright_black)
          cur_x += empty_w
        end

        buffer.put_char(cur_x, y, ']', fg: Color.bright_black)
        cur_x += 2

        buffer.put_string(cur_x, y, pct_text, fg: c, bold: true)
      end

      # Class convenience method returning styled gauge string
      def self.to_string(
        ratio : Float64,
        label : String? = nil,
        color : Color | Symbol | String | Nil = nil,
        width : Int32? = nil,
        filled_char : Char = '█',
        empty_char : Char = '░',
        ansi : Bool? = nil,
        theme : Theme? = nil,
      ) : String
        g = Gauge.new(ratio: ratio, label: label, color: color, filled_char: filled_char, empty_char: empty_char)
        g.to_print_s(width: width, color: ansi, theme: theme)
      end

      # Class convenience method printing styled gauge directly to IO
      def self.print(
        ratio : Float64,
        label : String? = nil,
        io : IO = STDOUT,
        color : Color | Symbol | String | Nil = nil,
        width : Int32? = nil,
        filled_char : Char = '█',
        empty_char : Char = '░',
        ansi : Bool? = nil,
        theme : Theme? = nil,
      ) : Nil
        io.puts to_string(
          ratio: ratio,
          label: label,
          color: color,
          width: width,
          filled_char: filled_char,
          empty_char: empty_char,
          ansi: ansi,
          theme: theme
        )
      end
    end
  end
end
