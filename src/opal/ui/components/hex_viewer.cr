require "../control"
require "../buffer"
require "../../style/color"
require "../../style/visual_width"

module Opal
  module UI
    # Hexadecimal memory and binary dump component displaying addresses,
    # hex byte pairs with mid-row division, and ASCII text representation.
    class HexViewer < Control
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

      # Cached layout coordinates for mouse interaction
      @last_x : Int32 = 0
      @last_y : Int32 = 0
      @last_w : Int32 = 0
      @last_h : Int32 = 0

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
        super()
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

      def handle_key(event : Terminal::KeyEvent) : Bool
        case event.name
        when "up", "k"
          if sel = @selected_byte
            @selected_byte = Math.max(0, sel - @bytes_per_row)
            # Ensure visible
            row = @selected_byte.not_nil! // @bytes_per_row
            @scroll_offset = Math.min(@scroll_offset, row)
          else
            scroll_up(1)
          end
          true
        when "down", "j"
          if sel = @selected_byte
            @selected_byte = Math.min(@bytes.size - 1, sel + @bytes_per_row)
            # Ensure visible
            row = @selected_byte.not_nil! // @bytes_per_row
            if @last_h > 0 && row >= @scroll_offset + @last_h
              @scroll_offset = row - @last_h + 1
            end
          else
            scroll_down(1)
          end
          true
        when "left", "h"
          if sel = @selected_byte
            @selected_byte = Math.max(0, sel - 1)
          else
            @selected_byte = @scroll_offset * @bytes_per_row
          end
          true
        when "right", "l"
          if sel = @selected_byte
            @selected_byte = Math.min(@bytes.size - 1, sel + 1)
          else
            @selected_byte = @scroll_offset * @bytes_per_row
          end
          true
        when "page_up", "pageup"
          scroll_up(@last_h > 0 ? @last_h : 8)
          true
        when "page_down", "pagedown"
          scroll_down(@last_h > 0 ? @last_h : 8)
          true
        when "home"
          @selected_byte = 0
          @scroll_offset = 0
          true
        when "end"
          @selected_byte = Math.max(0, @bytes.size - 1)
          @scroll_offset = Math.max(0, total_rows - (@last_h > 0 ? @last_h : 8))
          true
        else
          false
        end
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        case event.button
        when Terminal::MouseButton::WheelUp
          scroll_up(2)
          return true
        when Terminal::MouseButton::WheelDown
          scroll_down(2)
          return true
        end

        if event.button == Terminal::MouseButton::Left && event.action == Terminal::MouseAction::Press
          if event.x >= @last_x && event.x < @last_x + @last_w &&
             event.y >= @last_y && event.y < @last_y + @last_h
            row_idx = event.y - @last_y
            row_num = @scroll_offset + row_idx
            return false if row_num >= total_rows

            rel_x = event.x - @last_x
            addr_w = 12 # "0x00000000  "

            # Check if in hex area
            if rel_x >= addr_w
              hex_offset = rel_x - addr_w
              # Check byte position in hex columns
              # Each byte has 3 chars ("XX "), plus mid-row division space
              col = if hex_offset < (@bytes_per_row // 2) * 3
                      hex_offset // 3
                    else
                      (hex_offset - 1) // 3
                    end

              if col >= 0 && col < @bytes_per_row
                idx = row_num * @bytes_per_row + col
                if idx < @bytes.size
                  @selected_byte = idx
                  return true
                end
              end

              # Check if in ASCII column area
              ascii_start = addr_w + (@bytes_per_row * 3) + 2
              ascii_offset = rel_x - ascii_start
              if ascii_offset >= 0 && ascii_offset < @bytes_per_row
                idx = row_num * @bytes_per_row + ascii_offset
                if idx < @bytes.size
                  @selected_byte = idx
                  return true
                end
              end
            end

            return true
          end
        end

        false
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0 || @bytes.empty?

        @last_x = x
        @last_y = y
        @last_w = width
        @last_h = height

        buffer.with_clip(x, y, width, height) do
          rows_to_render = Math.min(height, total_rows - @scroll_offset)

          (0...rows_to_render).each do |row_idx|
            row_num = @scroll_offset + row_idx
            byte_offset = row_num * @bytes_per_row
            cur_y = y + row_idx
            cur_x = x

            # 1. Render Address
            addr = @base_address + byte_offset
            addr_str = "0x" + addr.to_s(16).rjust(8, '0') + "  "
            avail_w = Math.max(0, (x + width) - cur_x)
            buffer.put_string(cur_x, cur_y, addr_str, fg: @address_fg, max_width: avail_w)
            cur_x += VisualWidth.width(addr_str)

            # 2. Render Hex Bytes
            ascii_chars = IO::Memory.new
            (0...@bytes_per_row).each do |i|
              break if cur_x >= x + width
              idx = byte_offset + i
              if idx < @bytes.size
                b = @bytes[idx]
                is_sel = (@selected_byte == idx)
                hex_pair = b.to_s(16).rjust(2, '0')

                fg = is_sel ? @selected_fg : (b == 0 ? @zero_fg : @non_zero_fg)
                bg = is_sel ? @selected_bg : Color.none

                avail_hex_w = Math.max(0, (x + width) - cur_x)
                buffer.put_string(cur_x, cur_y, hex_pair, fg: fg, bg: bg, bold: is_sel, max_width: avail_hex_w)
                cur_x += 2

                # Add mid-row split space
                if cur_x < x + width
                  if i == (@bytes_per_row // 2) - 1
                    buffer.put_string(cur_x, cur_y, "  ", max_width: Math.max(0, (x + width) - cur_x))
                    cur_x += 2
                  else
                    buffer.put_string(cur_x, cur_y, " ", max_width: Math.max(0, (x + width) - cur_x))
                    cur_x += 1
                  end
                end

                # Printable ASCII char
                ascii_chars << (b >= 32 && b <= 126 ? b.chr : '.')
              else
                # Padding for incomplete last row
                buffer.put_string(cur_x, cur_y, "   ", max_width: Math.max(0, (x + width) - cur_x))
                cur_x += (i == (@bytes_per_row // 2) - 1 ? 4 : 3)
                ascii_chars << ' '
              end
            end

            # 3. Render ASCII representation
            if cur_x < x + width
              buffer.put_string(cur_x, cur_y, "│", fg: @address_fg, max_width: Math.max(0, (x + width) - cur_x))
              cur_x += 1
              ascii_str = ascii_chars.to_s
              avail_ascii_w = Math.max(0, (x + width) - cur_x)
              buffer.put_string(cur_x, cur_y, ascii_str, fg: @ascii_fg, max_width: avail_ascii_w)
              cur_x += Math.min(avail_ascii_w, VisualWidth.width(ascii_str))
              if cur_x < x + width
                buffer.put_string(cur_x, cur_y, "│", fg: @address_fg, max_width: Math.max(0, (x + width) - cur_x))
              end
            end
          end
        end
      end
    end
  end
end
