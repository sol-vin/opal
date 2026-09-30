require "../element"
require "../../style/color"
require "../../style/visual_width"

module Opal
  module UI
    # Formatted data table component with column alignment, headers,
    # row selection cursor, windowed scrolling pagination, and cell truncation.
    class Table < Control
      property headers : Array(String)
      property rows : Array(Array(String))
      property header_fg : Color?
      property header_bg : Color?
      property border_fg : Color?
      property selected_index : Int32?
      property visible_rows : Int32?
      property scroll_offset : Int32
      property? truncate : Bool
      property? zebra : Bool
      property selected_fg : Color?
      property selected_bg : Color?
      property zebra_bg : Color?
      property cursor_char : String?
      property divider_char : String?
      property horizontal_char : Char?
      property junction_char : Char?
      property vertical_char : Char?
      property border_style : Border?

      def initialize(
        @headers : Array(String) = [] of String,
        @rows : Array(Array(String)) = [] of Array(String),
        header_fg : Color | Symbol | String | Nil = nil,
        header_bg : Color | Symbol | String | Nil = nil,
        border_fg : Color | Symbol | String | Nil = nil,
        @selected_index : Int32? = nil,
        @visible_rows : Int32? = nil,
        @scroll_offset : Int32 = 0,
        @truncate : Bool = true,
        @zebra : Bool = false,
        selected_fg : Color | Symbol | String | Nil = nil,
        selected_bg : Color | Symbol | String | Nil = nil,
        zebra_bg : Color | Symbol | String | Nil = nil,
        @cursor_char : String? = nil,
        @divider_char : String? = nil,
        border_style : Border | Symbol | String | Nil = nil,
      )
        @header_fg = header_fg ? Color.from(header_fg) : nil
        @header_bg = header_bg ? Color.from(header_bg) : nil
        @border_fg = border_fg ? Color.from(border_fg) : nil
        @selected_fg = selected_fg ? Color.from(selected_fg) : nil
        @selected_bg = selected_bg ? Color.from(selected_bg) : nil
        @zebra_bg = zebra_bg ? Color.from(zebra_bg) : nil
        @border_style = border_style ? Border.from(border_style) : nil
        super()
      end

      def row(cells : Array(String)) : self
        @rows << cells
        self
      end

      def add_row(cells : Array(String)) : self
        row(cells)
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

      def handle_key(key : Terminal::KeyEvent) : Bool
        case key.name
        when "up", "ctrl+p"
          move_up
          true
        when "down", "ctrl+n"
          move_down
          true
        when "pageup", "page_up"
          page_up
          true
        when "pagedown", "page_down"
          page_down
          true
        when "home"
          self.select(0)
          true
        when "end"
          self.select(@rows.size - 1)
          true
        else
          false
        end
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        case event.button
        when Terminal::MouseButton::WheelUp
          move_up(3)
          true
        when Terminal::MouseButton::WheelDown
          move_down(3)
          true
        else
          false
        end
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

        th = current_theme
        glyphs = th.glyphs
        h_fg = @header_fg || th.primary
        h_bg = @header_bg || Color.none
        b_fg = @border_fg || th.border
        s_fg = @selected_fg || th.background
        s_bg = @selected_bg || th.accent
        z_bg = @zebra_bg || (th.background.relative_luminance < 0.5 ? th.background.lighten(0.04) : th.background.darken(0.04))

        # Erase entire table viewport with spaces to eliminate dirty trailing cells
        buffer.fill(x, y, width, height, ' ')

        col_widths = calculate_column_widths
        cur_y = y

        # Render Header
        unless @headers.empty?
          render_row(buffer, x, cur_y, @headers, col_widths, fg: h_fg, bg: h_bg, bold: true, width: width)
          cur_y += 1

          # Divider line: mathematical alignment with columns!
          divider_str = IO::Memory.new
          horiz_char = @horizontal_char || glyphs.table_horizontal
          junc_char = @junction_char || glyphs.table_junction
          div_char = @divider_char || "#{horiz_char}#{junc_char}#{horiz_char}"
          col_widths.each_with_index do |cw, idx|
            divider_str << div_char if idx > 0
            divider_str << (horiz_char.to_s * cw)
          end
          buffer.put_string(x, cur_y, divider_str.to_s, fg: b_fg, max_width: width)
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
          row_bg = if is_selected
                     s_bg
                   elsif @zebra && actual_idx.odd?
                     z_bg
                   else
                     Color.none
                   end
          row_fg = is_selected ? s_fg : Color.none

          render_row(
            buffer, x, cur_y, r, col_widths,
            fg: row_fg,
            bg: row_bg,
            bold: is_selected,
            dim: @zebra && actual_idx.odd? && !is_selected && @zebra_bg.nil?,
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

          # If selected or row background, fill background across column strictly within width
          if bg.type != Color::Type::None
            (0...cw).each do |cx|
              break if cur_x + cx >= x + width
              buffer.put_char(cur_x + cx, y, ' ', fg: fg, bg: bg)
            end
          end

          avail_w = Math.min(cw, Math.max(0, (x + width) - cur_x))
          buffer.put_string(
            cur_x, y, display_text,
            fg: fg,
            bg: bg,
            bold: bold,
            dim: dim,
            max_width: avail_w
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
