require "../element"
require "../buffer"
require "../../style/color"
require "../../style/border"
require "../../style/visual_width"
require "../../input/fuzzy"
require "../../terminal/driver"

module Opal
  module UI
    # Interactive fuzzy filterable list with search query and optional preview pane.
    class FilterList < Control
      getter title : String?
      getter items : Array(String)
      property query : String = ""
      property cursor : Int32 = 0
      property preview_fn : Proc(String, String)?

      def initialize(
        @items : Array(String),
        @title : String? = nil,
        @preview_fn : Proc(String, String)? = nil,
      )
        super()
      end

      def matches : Array(Input::FuzzyMatch(String))
        Input::Fuzzy.filter(@query, @items)
      end

      def selected_item : String?
        m = matches
        return nil if m.empty?
        idx = @cursor.clamp(0, Math.max(0, m.size - 1))
        m[idx].item
      end

      def cursor_up : Nil
        @cursor = Math.max(0, @cursor - 1)
      end

      def cursor_down : Nil
        max_idx = Math.max(0, matches.size - 1)
        @cursor = Math.min(max_idx, @cursor + 1)
      end

      def append_char(ch : Char) : Nil
        @query += ch
        @cursor = 0
      end

      def backspace : Nil
        return if @query.empty?
        @query = @query[0...-1]
        @cursor = 0
      end

      def handle_key(key : Terminal::KeyEvent) : Bool
        case key.name
        when "up", "ctrl+p"
          cursor_up
          true
        when "down", "ctrl+n"
          cursor_down
          true
        when "backspace"
          backspace
          true
        when "escape"
          if @query.empty?
            false
          else
            @query = ""
            @cursor = 0
            true
          end
        else
          if key.name.size == 1
            append_char(key.name[0])
            true
          elsif (ch = key.char) && !key.ctrl? && !key.alt?
            append_char(ch)
            true
          else
            false
          end
        end
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        case event.button
        when Terminal::MouseButton::WheelUp
          cursor_up
          true
        when Terminal::MouseButton::WheelDown
          cursor_down
          true
        else
          false
        end
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        {available_w, available_h}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width < 10 || height < 4

        # Erase entire filter list area with spaces to ensure zero dirty cells
        buffer.fill(x, y, width, height, ' ')

        cur_y = y

        # Title
        if t = @title
          buffer.put_string(x, cur_y, t, fg: Color.cyan, bold: true, max_width: width)
          cur_y += 1
          buffer.put_string(x, cur_y, "─" * Math.min(width, VisualWidth.width(t) + 4), fg: Color.bright_black)
          cur_y += 1
        end

        # Search Query Bar
        buffer.put_string(x, cur_y, "> ", fg: Color.cyan, bold: true)
        q_display = @query.empty? ? "Type to filter..." : @query
        q_fg = @query.empty? ? Color.bright_black : Color.white
        buffer.put_string(x + 2, cur_y, q_display, fg: q_fg)
        buffer.put_char(x + 2 + VisualWidth.width(@query), cur_y, '█', fg: Color.cyan) unless @query.empty?
        cur_y += 1

        buffer.put_string(x, cur_y, "─" * width, fg: Color.bright_black)
        cur_y += 1

        matched = matches
        list_h = (y + height) - cur_y

        has_preview = !@preview_fn.nil?
        list_w = has_preview ? (width // 2) - 1 : width

        # Render list items
        if matched.empty?
          buffer.put_string(x + 2, cur_y, "No matching items", fg: Color.bright_black, italic: true)
        else
          # Ensure cursor in view
          scroll_offset = 0
          if @cursor >= list_h
            scroll_offset = @cursor - list_h + 1
          end

          (0...list_h).each do |line_idx|
            match_idx = scroll_offset + line_idx
            break if match_idx >= matched.size

            m = matched[match_idx]
            is_active = (match_idx == @cursor)
            row_y = cur_y + line_idx

            if is_active
              buffer.put_string(x, row_y, "> ", fg: Color.cyan, bold: true)
            else
              buffer.put_string(x, row_y, "  ")
            end

            # Render text with highlighted runes
            target_str = m.target
            col_x = x + 2
            target_str.each_char_with_index do |ch, ch_idx|
              break if col_x >= x + list_w - 1
              is_matched = m.matched_indices.includes?(ch_idx)

              if is_active
                if is_matched
                  buffer.put_char(col_x, row_y, ch, fg: Color.bright_cyan, bg: Color.bright_black, bold: true, underline: true)
                else
                  buffer.put_char(col_x, row_y, ch, fg: Color.white, bg: Color.bright_black)
                end
              else
                if is_matched
                  buffer.put_char(col_x, row_y, ch, fg: Color.cyan, bold: true)
                else
                  buffer.put_char(col_x, row_y, ch, fg: Color.white)
                end
              end

              col_x += VisualWidth.char_width(ch)
            end
          end
        end

        # Render Preview Pane if provided
        if has_preview && (fn = @preview_fn)
          divider_x = x + list_w
          (cur_y...(y + height)).each do |div_y|
            buffer.put_char(divider_x, div_y, '│', fg: Color.bright_black)
          end

          preview_x = divider_x + 2
          preview_w = (x + width) - preview_x

          if sel = selected_item
            preview_content = fn.call(sel)
            prev_lines = preview_content.split('\n')
            prev_lines.each_with_index do |pline, pidx|
              break if cur_y + pidx >= y + height
              buffer.put_string(preview_x, cur_y + pidx, pline, fg: Color.bright_white, max_width: preview_w)
            end
          end
        end
      end
    end
  end

  # High-level interactive filter prompt helper.
  def self.filter(
    items : Array(String),
    title : String = "Filter Items",
    preview : Proc(String, String)? = nil,
    driver : Terminal::Driver? = nil,
  ) : String?
    drv = driver || Terminal.default_driver
    filter_list = UI::FilterList.new(items: items, title: title, preview_fn: preview)

    render_frame = -> {
      w, h = drv.size
      buf = UI::Buffer.new(w, h)
      filter_list.render(buf, 0, 0, w, h)
      drv.write(Terminal::Screen::CLEAR_ALL)
      drv.write(Terminal::Screen.move_to(1, 1))
      drv.write(buf.to_s)
      drv.flush
    }

    selected : String? = nil

    drv.raw_mode do
      drv.hide_cursor
      render_frame.call

      loop do
        event = drv.read_event
        next unless event
        should_redraw = false

        case event
        when Terminal::KeyEvent
          case event.name
          when "up", "ctrl+p"
            filter_list.cursor_up
            should_redraw = true
          when "down", "ctrl+n"
            filter_list.cursor_down
            should_redraw = true
          when "enter"
            selected = filter_list.selected_item
            break
          when "escape", "ctrl+c"
            break
          when "backspace"
            filter_list.backspace
            should_redraw = true
          else
            if event.name.size == 1
              filter_list.append_char(event.name[0])
              should_redraw = true
            end
          end
        end

        render_frame.call if should_redraw
      end
    ensure
      drv.show_cursor
    end

    selected
  end
end
