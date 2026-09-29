require "../element"
require "../../style/color"
require "../../style/visual_width"

module Opal
  module UI
    # Formatted data table component with column alignment and headers.
    class Table < Element
      property headers : Array(String)
      property rows : Array(Array(String))
      property header_fg : Color
      property border_fg : Color

      def initialize(
        @headers : Array(String) = [] of String,
        @rows : Array(Array(String)) = [] of Array(String),
        header_fg : Color | Symbol | String = :cyan,
        border_fg : Color | Symbol | String = Color.none,
      )
        @header_fg = Color.from(header_fg)
        @border_fg = Color.from(border_fg)
      end

      def row(cells : Array(String)) : self
        @rows << cells
        self
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        col_widths = calculate_column_widths
        total_w = col_widths.sum + (col_widths.size * 3) + 1
        total_h = @rows.size + (@headers.empty? ? 0 : 2)
        {Math.min(total_w, available_w), Math.min(total_h, available_h)}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0

        col_widths = calculate_column_widths
        cur_y = y

        # Render Header
        unless @headers.empty?
          render_row(buffer, x, cur_y, @headers, col_widths, fg: @header_fg, bold: true, width: width)
          cur_y += 1

          # Divider line
          divider_str = IO::Memory.new
          col_widths.each_with_index do |cw, idx|
            divider_str << (idx == 0 ? "─" : "─┼─")
            divider_str << ("─" * cw)
          end
          buffer.put_string(x, cur_y, divider_str.to_s, fg: @border_fg, max_width: width)
          cur_y += 1
        end

        # Render Data Rows
        @rows.each_with_index do |r, r_idx|
          break if cur_y >= y + height
          dim = (r_idx % 2 == 1)
          render_row(buffer, x, cur_y, r, col_widths, dim: dim, width: width)
          cur_y += 1
        end
      end

      private def calculate_column_widths : Array(Int32)
        num_cols = Math.max(@headers.size, @rows.map(&.size).max? || 0)
        widths = Array.new(num_cols, 0)

        @headers.each_with_index do |h, i|
          widths[i] = Math.max(widths[i], VisualWidth.width(h))
        end

        @rows.each do |row_cells|
          row_cells.each_with_index do |c, i|
            break if i >= num_cols
            widths[i] = Math.max(widths[i], VisualWidth.width(c))
          end
        end

        widths
      end

      private def render_row(
        buffer : Buffer,
        x : Int32,
        y : Int32,
        cells : Array(String),
        col_widths : Array(Int32),
        fg : Color = Color.none,
        bold : Bool = false,
        dim : Bool = false,
        width : Int32 = 80,
      ) : Nil
        cur_x = x

        cells.each_with_index do |cell_text, col_idx|
          break if cur_x >= x + width
          cw = col_idx < col_widths.size ? col_widths[col_idx] : 10

          buffer.put_string(
            cur_x, y, cell_text,
            fg: fg,
            bold: bold,
            dim: dim,
            max_width: cw
          )

          cur_x += cw + 3 # 3 spaces padding between columns
        end
      end
    end
  end
end
