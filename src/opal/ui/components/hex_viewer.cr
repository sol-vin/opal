require "../element"
require "../buffer"
require "../../style/color"
require "../../style/visual_width"

module Opal
  module UI
    # Hexadecimal memory and binary dump component displaying addresses,
    # hex byte pairs with mid-row division, and ASCII text representation.
    class HexViewer < Element
      property bytes : Slice(UInt8)
      property base_address : UInt64
      property bytes_per_row : Int32
      property scroll_offset : Int32
      property selected_byte : Int32?
      property address_fg : Color
      property zero_fg : Color
      property non_zero_fg : Color
      property ascii_fg : Color
      property selected_fg : Color
      property selected_bg : Color

      def initialize(
        bytes : Bytes | Slice(UInt8) | Array(UInt8),
        @base_address : UInt64 = 0_u64,
        @bytes_per_row : Int32 = 16,
        @scroll_offset : Int32 = 0,
        @selected_byte : Int32? = nil,
        address_fg : Color | Symbol | String = :dark_gray,
        zero_fg : Color | Symbol | String = :dark_gray,
        non_zero_fg : Color | Symbol | String = Color.none,
        ascii_fg : Color | Symbol | String = :cyan,
        selected_fg : Color | Symbol | String = :black,
        selected_bg : Color | Symbol | String = :yellow,
      )
        @bytes = if bytes.is_a?(Array(UInt8))
                   Slice.new(bytes.to_unsafe, bytes.size)
                 else
                   bytes
                 end
        @address_fg = Color.from(address_fg)
        @zero_fg = Color.from(zero_fg)
        @non_zero_fg = Color.from(non_zero_fg)
        @ascii_fg = Color.from(ascii_fg)
        @selected_fg = Color.from(selected_fg)
        @selected_bg = Color.from(selected_bg)
      end

      def total_rows : Int32
        return 0 if @bytes.empty?
        ((@bytes.size + @bytes_per_row - 1) / @bytes_per_row).to_i
      end

      def scroll_up(rows : Int32 = 1) : Nil
        @scroll_offset = Math.max(0, @scroll_offset - rows)
      end

      def scroll_down(rows : Int32 = 1) : Nil
        max_offset = Math.max(0, total_rows - 1)
        @scroll_offset = Math.min(max_offset, @scroll_offset + rows)
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        # Address (10 chars) + '  ' + 16 bytes * 3 chars + ' ' + 2 (borders) + 16 (ascii) = ~78 chars
        addr_w = 12
        hex_w = (@bytes_per_row * 3) + 2
        ascii_w = @bytes_per_row + 2
        total_w = addr_w + hex_w + ascii_w
        {Math.min(available_w, total_w), Math.min(available_h, total_rows)}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0 || @bytes.empty?

        rows_to_render = Math.min(height, total_rows - @scroll_offset)

        (0...rows_to_render).each do |row_idx|
          row_num = @scroll_offset + row_idx
          byte_offset = row_num * @bytes_per_row
          cur_y = y + row_idx
          cur_x = x

          # 1. Render Address
          addr = @base_address + byte_offset
          addr_str = "0x" + addr.to_s(16).rjust(8, '0') + "  "
          buffer.put_string(cur_x, cur_y, addr_str, fg: @address_fg)
          cur_x += VisualWidth.width(addr_str)

          # 2. Render Hex Bytes
          ascii_chars = IO::Memory.new
          (0...@bytes_per_row).each do |i|
            idx = byte_offset + i
            if idx < @bytes.size
              b = @bytes[idx]
              is_sel = (@selected_byte == idx)
              hex_pair = b.to_s(16).rjust(2, '0')

              fg = is_sel ? @selected_fg : (b == 0 ? @zero_fg : @non_zero_fg)
              bg = is_sel ? @selected_bg : Color.none

              buffer.put_string(cur_x, cur_y, hex_pair, fg: fg, bg: bg, bold: is_sel)
              cur_x += 2

              # Add mid-row split space
              if i == (@bytes_per_row / 2) - 1
                buffer.put_string(cur_x, cur_y, "  ")
                cur_x += 2
              else
                buffer.put_string(cur_x, cur_y, " ")
                cur_x += 1
              end

              # Printable ASCII char
              ascii_chars << (b >= 32 && b <= 126 ? b.chr : '.')
            else
              # Padding for incomplete last row
              buffer.put_string(cur_x, cur_y, "   ")
              cur_x += (i == (@bytes_per_row / 2) - 1 ? 4 : 3)
              ascii_chars << ' '
            end
          end

          # 3. Render ASCII representation
          buffer.put_string(cur_x, cur_y, "│", fg: @address_fg)
          cur_x += 1
          buffer.put_string(cur_x, cur_y, ascii_chars.to_s, fg: @ascii_fg)
          cur_x += ascii_chars.to_s.size
          buffer.put_string(cur_x, cur_y, "│", fg: @address_fg)
        end
      end
    end
  end
end
