require "../element"
require "../../style/color"
require "../../style/visual_width"

module Opal
  module UI
    # Formatted data table component with column alignment, headers,
    # row selection cursor, windowed scrolling pagination, and cell truncation.
    class Table < Element
      property headers : Array(String)
      property rows : Array(Array(String))
      property header_fg : Color
      property border_fg : Color
      property selected_index : Int32?
      property visible_rows : Int32?
      property scroll_offset : Int32
      property? truncate : Bool
      property? zebra : Bool
      property selected_fg : Color
      property selected_bg : Color
      property cursor_char : String

      def initialize(
        @headers : Array(String) = [] of String,
        @rows : Array(Array(String)) = [] of Array(String),
        header_fg : Color | Symbol | String = :cyan,
        border_fg : Color | Symbol | String = Color.none,
        @selected_index : Int32? = nil,
        @visible_rows : Int32? = nil,
        @scroll_offset : Int32 = 0,
        @truncate : Bool = true,
        @zebra : Bool = false,
        selected_fg : Color | Symbol | String = :black,
        selected_bg : Color | Symbol | String = :cyan,
        @cursor_char : String = "▶ ",
      )
        @header_fg = Color.from(header_fg)
        @border_fg = Color.from(border_fg)
        @selected_fg = Color.from(selected_fg)
        @selected_bg = Color.from(selected_bg)
      end

      def row(cells : Array(String)) : self
        @rows << cells
        self
      end

      def select(idx : Int32?) : self
        @selected_index = idx ? idx.clamp(0, Math.max(0, @rows.size - 1)) : nil
        ensure_visible_selection
        self
      end

      def move_up(count : Int32 = 1) : self
        return self if @rows.empty?
        cur = @selected_index || 0
        @selected_index = Math.max(0, cur - count)
        ensure_visible_selection
        self
      end

      def move_down(count : Int32 = 1) : self
        return self if @rows.empty?
        cur = @selected_index || -1
        @selected_index = Math.min(@rows.size - 1, cur + count)
        ensure_visible_selection
        self
      end

      def page_up(count : Int32 = 10) : self
        move_up(count)
      end

      def page_down(count : Int32 = 10) : self
        move_down(count)
      end

      private def ensure_visible_selection : Nil
        if sel = @selected_index
          if sel < @scroll_offset
            @scroll_offset = sel
          elsif vr = @visible_rows
            if sel >= @scroll_offset + vr
              @scroll_offset = sel - vr + 1
            end
          end
        end
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        col_widths = calculate_column_widths
        total_w = col_widths.sum + (col_widths.size * 3) + 1
        rendered_count = @visible_rows || @rows.size
        total_h = rendered_count + (@headers.empty? ? 0 : 2)
        {Math.min(total_w, available_w), Math.min(total_h, available_h)}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0

        # Erase entire table viewport with spaces to eliminate dirty trailing cells
        buffer.fill(x, y, width, height, ' ')

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

        # Calculate visible window of rows
        max_rows = @visible_rows || height - (@headers.empty? ? 0 : 2)
        slice_end = Math.min(@rows.size, @scroll_offset + max_rows)
        row_slice = @rows[@scroll_offset...slice_end]? || [] of Array(String)

        # Render Data Rows
        row_slice.each_with_index do |r, offset_idx|
          break if cur_y >= y + height
          actual_idx = @scroll_offset + offset_idx
          is_selected = (@selected_index == actual_idx)
          dim = @zebra ? (actual_idx.odd? && !is_selected) : false

          render_row(
            buffer, x, cur_y, r, col_widths,
            fg: is_selected ? @selected_fg : Color.none,
            bg: is_selected ? @selected_bg : Color.none,
            bold: is_selected,
            dim: dim,
            width: width,
            is_selected: is_selected
          )
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
        bg : Color = Color.none,
        bold : Bool = false,
        dim : Bool = false,
        width : Int32 = 80,
        is_selected : Bool = false,
      ) : Nil
        cur_x = x

        cells.each_with_index do |cell_text, col_idx|
          break if cur_x >= x + width
          cw = col_idx < col_widths.size ? col_widths[col_idx] : 10

          display_text = cell_text
          if @truncate && VisualWidth.width(display_text) > cw
            if cw > 1
              display_text = truncate_text(display_text, cw)
            end
          end

          # If selected, fill background across column
          if is_selected
            (0...cw).each do |cx|
              buffer.put_char(cur_x + cx, y, ' ', fg: fg, bg: bg)
            end
          end

          buffer.put_string(
            cur_x, y, display_text,
            fg: fg,
            bg: bg,
            bold: bold,
            dim: dim,
            max_width: cw
          )

          cur_x += cw + 3 # 3 spaces padding between columns
        end
      end

      private def truncate_text(text : String, max_w : Int32) : String
        return text if VisualWidth.width(text) <= max_w
        avail = Math.max(1, max_w - 1)
        res = IO::Memory.new
        current_w = 0

        text.each_char do |ch|
          cw = VisualWidth.char_width(ch)
          break if current_w + cw > avail
          res << ch
          current_w += cw
        end
        res << "…"
        res.to_s
      end
    end
  end
end
