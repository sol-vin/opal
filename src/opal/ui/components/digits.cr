require "../element"
require "../../style/color"
require "../../style/visual_width"

module Opal
  module UI
    # Large 3x5 block character digital number and clock display inspired by Python Textual's Digits.
    # Renders numbers 0-9, colon :, dash -, plus +, slash /, and periods in bold block characters.
    class Digits < Element
      property text : String
      property fg : Color
      property bg : Color
      property? bold : Bool

      GLYPH_3X5 = {
        '0' => [
          "█▀█",
          "█ █",
          "█ █",
          "█ █",
          "▀▀▀",
        ],
        '1' => [
          " █ ",
          "██ ",
          " █ ",
          " █ ",
          "▀▀▀",
        ],
        '2' => [
          "█▀█",
          "  █",
          "█▀█",
          "█  ",
          "▀▀▀",
        ],
        '3' => [
          "█▀█",
          "  █",
          " ▀█",
          "  █",
          "▀▀▀",
        ],
        '4' => [
          "█ █",
          "█ █",
          "▀▀█",
          "  █",
          "  ▀",
        ],
        '5' => [
          "█▀█",
          "█  ",
          "▀▀█",
          "  █",
          "▀▀▀",
        ],
        '6' => [
          "█▀█",
          "█  ",
          "█▀█",
          "█ █",
          "▀▀▀",
        ],
        '7' => [
          "▀▀█",
          "  █",
          "  █",
          "  █",
          "  ▀",
        ],
        '8' => [
          "█▀█",
          "█ █",
          "█▀█",
          "█ █",
          "▀▀▀",
        ],
        '9' => [
          "█▀█",
          "█ █",
          "▀▀█",
          "  █",
          "▀▀▀",
        ],
        ':' => [
          " ",
          "●",
          " ",
          "●",
          " ",
        ],
        '.' => [
          " ",
          " ",
          " ",
          " ",
          "▀",
        ],
        '-' => [
          "   ",
          "   ",
          "▀▀▀",
          "   ",
          "   ",
        ],
        '+' => [
          "   ",
          " █ ",
          "▀█▀",
          " █ ",
          "   ",
        ],
        '/' => [
          "  █",
          "  █",
          " █ ",
          "█  ",
          "█  ",
        ],
        '%' => [
          "▀ █",
          "  █",
          " █ ",
          "█  ",
          "█ ▀",
        ],
        ' ' => [
          "  ",
          "  ",
          "  ",
          "  ",
          "  ",
        ],
      }

      def initialize(
        @text : String,
        fg : Color | Symbol | String = :bright_cyan,
        bg : Color | Symbol | String = Color.none,
        @bold : Bool = true,
      )
        @fg = Color.from(fg)
        @bg = Color.from(bg)
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        total_w = 0
        @text.each_char_with_index do |ch, idx|
          g = GLYPH_3X5[ch]? || GLYPH_3X5[' ']?
          w = g ? g[0].size : 3
          total_w += w + (idx > 0 ? 1 : 0)
        end
        {Math.min(available_w, total_w), Math.min(available_h, 5)}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0 || @text.empty?

        cur_x = x
        char_count = 0

        @text.each_char do |ch|
          break if cur_x >= x + width

          glyph_rows = GLYPH_3X5[ch]? || GLYPH_3X5[' ']?
          next unless glyph_rows

          glyph_w = glyph_rows[0].size
          avail_w = (x + width) - cur_x
          break if avail_w <= 0

          # Draw the 5 rows of this glyph
          (0...5).each do |row_idx|
            target_y = y + row_idx
            break if target_y >= y + height

            row_str = glyph_rows[row_idx]
            buffer.put_string(
              cur_x, target_y, row_str,
              fg: @fg, bg: @bg, bold: @bold,
              max_width: avail_w
            )
          end

          cur_x += glyph_w + 1 # 1-column spacing between characters
          char_count += 1
        end
      end
    end
  end
end
