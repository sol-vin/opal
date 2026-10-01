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
      property? markdown_mode : Bool = false
      property? print_mode : Bool = false

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
        @print_mode : Bool = false,
      )
        @header_fg = header_fg ? Color.from(header_fg) : nil
        @header_bg = header_bg ? Color.from(header_bg) : nil
        @border_fg = border_fg ? Color.from(border_fg) : nil
        @selected_fg = selected_fg ? Color.from(selected_fg) : nil
        @selected_bg = selected_bg ? Color.from(selected_bg) : nil
        @zebra_bg = zebra_bg ? Color.from(zebra_bg) : nil
        if border_style == :markdown || border_style == "markdown"
          @markdown_mode = true
          @border_style = nil
        else
          @border_style = border_style ? Border.from(border_style) : nil
          @markdown_mode = false
        end
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

        if @markdown_mode
          render_markdown_table(buffer, x, y, width, height, col_widths, h_fg, h_bg, b_fg, s_fg, s_bg, z_bg)
          return
        end

        if b = @border_style
          render_bordered_table(buffer, x, y, width, height, col_widths, b, h_fg, h_bg, b_fg, s_fg, s_bg, z_bg)
          return
        end

        cur_y = y

        horiz_char = @horizontal_char || glyphs.table_horizontal
        junc_char = @junction_char || glyphs.table_junction
        div_char = @divider_char || "#{horiz_char}#{junc_char}#{horiz_char}"
        div_spacing = VisualWidth.width(div_char)

        buffer.with_clip(x, y, width, height) do
          # Render Header
          unless @headers.empty?
            render_row(buffer, x, cur_y, @headers, col_widths, fg: h_fg, bg: h_bg, bold: true, width: width, div_spacing: div_spacing)
            cur_y += 1
            return if cur_y >= y + height

            # Divider line: mathematical alignment with columns!
            divider_str = IO::Memory.new
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
              is_selected: is_selected,
              div_spacing: div_spacing
            )
            cur_y += 1
          end
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
        div_spacing : Int32 = 3,
      ) : Nil
        # If selected or row background, fill continuous background across entire visible table width
        if bg.type != Color::Type::None
          total_content_w = col_widths.sum + (Math.max(0, col_widths.size - 1) * div_spacing)
          highlight_w = Math.min(width, Math.max(total_content_w, is_selected ? width : 0))
          buffer.fill(x, y, highlight_w, 1, ' ', fg: fg, bg: bg)
        end

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

          avail_w = Math.min(cw, Math.max(0, (x + width) - cur_x))
          buffer.put_string(
            cur_x, y, display_text,
            fg: fg,
            bg: bg,
            bold: bold,
            dim: dim,
            max_width: avail_w
          )

          cur_x += cw + div_spacing
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

      # Preferred size in print mode: full row height and natural column width
      def preferred_print_size(available_w : Int32) : {Int32, Int32}
        col_widths = calculate_column_widths
        rendered_count = @rows.size
        extra_h = if @markdown_mode
                    @headers.empty? ? 0 : 2
                  elsif @border_style
                    (@headers.empty? ? 0 : 2) + 2
                  else
                    @headers.empty? ? 0 : 2
                  end
        total_w = col_widths.sum + (col_widths.size * 3) + 1
        total_h = rendered_count + extra_h
        {Math.max(total_w, available_w), total_h}
      end

      private def render_bordered_table(
        buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32,
        col_widths : Array(Int32), b : Border,
        h_fg : Color, h_bg : Color, b_fg : Color, s_fg : Color, s_bg : Color, z_bg : Color,
      ) : Nil
        top_l = b.top_left
        top_r = b.top_right
        bot_l = b.bottom_left
        bot_r = b.bottom_right
        h_char = b.top
        v_char = b.left

        top_j = case h_char
                when "─" then "┬"
                when "═" then "╦"
                when "━" then "┳"
                else          "+"
                end

        mid_j = case h_char
                when "─" then "┼"
                when "═" then "╬"
                when "━" then "╋"
                else          "+"
                end

        bot_j = case h_char
                when "─" then "┴"
                when "═" then "╩"
                when "━" then "┻"
                else          "+"
                end

        l_j = case h_char
              when "─" then "├"
              when "═" then "╠"
              when "━" then "┣"
              else          "+"
              end

        r_j = case h_char
              when "─" then "┤"
              when "═" then "╣"
              when "━" then "┫"
              else          "+"
              end

        cur_y = y
        buffer.with_clip(x, y, width, height) do
          # 1. Top border
          top_border = IO::Memory.new
          top_border << top_l
          col_widths.each_with_index do |cw, idx|
            top_border << top_j if idx > 0
            top_border << (h_char * (cw + 2))
          end
          top_border << top_r
          buffer.put_string(x, cur_y, top_border.to_s, fg: b_fg, max_width: width)
          cur_y += 1
          return if cur_y >= y + height

          # 2. Headers
          unless @headers.empty?
            hdr_str = IO::Memory.new
            hdr_str << v_char
            col_widths.each_with_index do |cw, idx|
              h = @headers[idx]? || ""
              v_w = VisualWidth.width(h)
              pad_len = Math.max(0, cw - v_w)
              hdr_str << " " << h << (" " * pad_len) << " " << v_char
            end
            buffer.put_string(x, cur_y, hdr_str.to_s, fg: h_fg, bg: h_bg, bold: true, max_width: width)
            cur_y += 1
            return if cur_y >= y + height

            # Header divider
            div_str = IO::Memory.new
            div_str << l_j
            col_widths.each_with_index do |cw, idx|
              div_str << mid_j if idx > 0
              div_str << (h_char * (cw + 2))
            end
            div_str << r_j
            buffer.put_string(x, cur_y, div_str.to_s, fg: b_fg, max_width: width)
            cur_y += 1
            return if cur_y >= y + height
          end

          # 3. Data rows
          max_rows = @visible_rows || (height - (@headers.empty? ? 2 : 4))
          slice_end = Math.min(@rows.size, @scroll_offset + Math.max(0, max_rows))
          row_slice = @rows[@scroll_offset...slice_end]? || [] of Array(String)

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

            row_str = IO::Memory.new
            row_str << v_char
            col_widths.each_with_index do |cw, idx|
              val = r[idx]? || ""
              v_w = VisualWidth.width(val)
              pad_len = Math.max(0, cw - v_w)
              row_str << " " << val << (" " * pad_len) << " " << v_char
            end
            buffer.put_string(x, cur_y, row_str.to_s, fg: row_fg, bg: row_bg, bold: is_selected, max_width: width)
            cur_y += 1
          end

          # 4. Bottom border
          if cur_y < y + height
            bot_border = IO::Memory.new
            bot_border << bot_l
            col_widths.each_with_index do |cw, idx|
              bot_border << bot_j if idx > 0
              bot_border << (h_char * (cw + 2))
            end
            bot_border << bot_r
            buffer.put_string(x, cur_y, bot_border.to_s, fg: b_fg, max_width: width)
            cur_y += 1
          end
        end
      end

      private def render_markdown_table(
        buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32,
        col_widths : Array(Int32),
        h_fg : Color, h_bg : Color, b_fg : Color, s_fg : Color, s_bg : Color, z_bg : Color,
      ) : Nil
        cur_y = y
        buffer.with_clip(x, y, width, height) do
          # 1. Headers
          unless @headers.empty?
            hdr_str = IO::Memory.new
            hdr_str << "| "
            col_widths.each_with_index do |cw, idx|
              h = @headers[idx]? || ""
              v_w = VisualWidth.width(h)
              pad_len = Math.max(0, cw - v_w)
              hdr_str << h << (" " * pad_len) << " | "
            end
            buffer.put_string(x, cur_y, hdr_str.to_s.rstrip, fg: h_fg, bg: h_bg, bold: true, max_width: width)
            cur_y += 1
            return if cur_y >= y + height

            # Header divider: |:---|:---|
            div_str = IO::Memory.new
            div_str << "|:"
            col_widths.each_with_index do |cw, idx|
              div_str << ("-" * Math.max(3, cw)) << ":|:"
            end
            res_div = div_str.to_s.rchop(":")
            res_div = res_div + "|" unless res_div.ends_with?('|')
            buffer.put_string(x, cur_y, res_div, fg: b_fg, max_width: width)
            cur_y += 1
            return if cur_y >= y + height
          end

          # 2. Data rows
          max_rows = @visible_rows || (height - (@headers.empty? ? 0 : 2))
          slice_end = Math.min(@rows.size, @scroll_offset + Math.max(0, max_rows))
          row_slice = @rows[@scroll_offset...slice_end]? || [] of Array(String)

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

            row_str = IO::Memory.new
            row_str << "| "
            col_widths.each_with_index do |cw, idx|
              val = r[idx]? || ""
              v_w = VisualWidth.width(val)
              pad_len = Math.max(0, cw - v_w)
              row_str << val << (" " * pad_len) << " | "
            end
            buffer.put_string(x, cur_y, row_str.to_s.rstrip, fg: row_fg, bg: row_bg, bold: is_selected, max_width: width)
            cur_y += 1
          end
        end
      end

      # Render hook for one-shot print mode: renders all rows without cursor or scroll clipping
      def render_print(buffer : Buffer, width : Int32, height : Int32) : Nil
        prev_sel = @selected_index
        prev_offset = @scroll_offset
        prev_vis = @visible_rows
        prev_print = @print_mode
        @selected_index = nil
        @scroll_offset = 0
        @visible_rows = @rows.size
        @print_mode = true
        begin
          render(buffer, 0, 0, width, height)
        ensure
          @selected_index = prev_sel
          @scroll_offset = prev_offset
          @visible_rows = prev_vis
          @print_mode = prev_print
        end
      end

      # Class convenience method returning styled table string
      def self.to_string(
        headers : Array(String),
        rows : Array(Array(String)),
        width : Int32? = nil,
        zebra : Bool = false,
        border_style : Border | Symbol | String | Nil = nil,
        theme : Theme? = nil,
        color : Bool? = nil,
      ) : String
        tbl = Table.new(
          headers: headers,
          rows: rows,
          zebra: zebra,
          border_style: border_style
        )
        tbl.to_print_s(width: width, color: color, theme: theme)
      end

      # Class convenience method printing styled table directly to IO
      def self.print(
        headers : Array(String),
        rows : Array(Array(String)),
        io : IO = STDOUT,
        width : Int32? = nil,
        zebra : Bool = false,
        border_style : Border | Symbol | String | Nil = nil,
        theme : Theme? = nil,
        color : Bool? = nil,
      ) : Nil
        io.print to_string(
          headers: headers,
          rows: rows,
          width: width,
          zebra: zebra,
          border_style: border_style,
          theme: theme,
          color: color
        )
      end
    end
  end
end
