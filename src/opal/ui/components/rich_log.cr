require "../control"
require "../../style/color"
require "../../style/visual_width"
require "./scrollbar"

module Opal
  module UI
    # Streaming, high-performance rolling log viewer inspired by Python Textual's RichLog.
    # Features automatic line-capping ring buffer, auto-scroll to bottom, user scroll lock,
    # ANSI escape sequence preservation, search/filtering, and scrollbar.
    class RichLog < Control
      property max_lines : Int32
      property? auto_scroll : Bool = true
      property? highlight_ansi : Bool = true
      property filter_query : String? = nil

      # Stored lines: array of raw strings
      getter lines : Deque(String)

      # Scroll offset (number of lines scrolled from top)
      property scroll_offset : Int32 = 0

      # Manipulable styling
      property bg : Color? = nil
      property text_fg : Color? = nil
      property border_fg : Color? = nil
      property scrollbar_thumb_fg : Color? = nil

      @last_x : Int32 = 0
      @last_y : Int32 = 0
      @last_w : Int32 = 0
      @last_h : Int32 = 0

      def initialize(
        @max_lines : Int32 = 1000,
        @auto_scroll : Bool = true,
        @highlight_ansi : Bool = true,
      )
        super()
        @lines = Deque(String).new(@max_lines)
      end

      # Appends a single line or multi-line string to the log buffer
      def write(text : String) : self
        text.each_line do |line|
          @lines.shift if @lines.size >= @max_lines
          @lines << line
        end

        if @auto_scroll
          scroll_to_end
        end
        self
      end

      # Alias for write
      def log(text : String) : self
        write(text)
      end

      # Clears all logged lines
      def clear : self
        @lines.clear
        @scroll_offset = 0
        self
      end

      # Scrolls to the very bottom
      def scroll_to_end : self
        @scroll_offset = Int32::MAX
        self
      end

      # Scrolls to the very top
      def scroll_to_top : self
        @scroll_offset = 0
        self
      end

      # Returns the filtered set of lines if a query is active, or all lines
      private def visible_lines : Array(String)
        if q = @filter_query
          return @lines.to_a if q.empty?
          lower_q = q.downcase
          @lines.select { |l| l.downcase.includes?(lower_q) }
        else
          @lines.to_a
        end
      end

      def handle_key(event : Terminal::KeyEvent) : Bool
        vl = visible_lines
        max_scroll = Math.max(0, vl.size - @last_h)

        case event.name
        when "up"
          @auto_scroll = false
          @scroll_offset = (@scroll_offset - 1).clamp(0, max_scroll)
          true
        when "down"
          @scroll_offset = (@scroll_offset + 1).clamp(0, max_scroll)
          @auto_scroll = true if @scroll_offset >= max_scroll
          true
        when "pageup", "page_up"
          @auto_scroll = false
          page_step = Math.max(1, @last_h - 2)
          @scroll_offset = (@scroll_offset - page_step).clamp(0, max_scroll)
          true
        when "pagedown", "page_down"
          page_step = Math.max(1, @last_h - 2)
          @scroll_offset = (@scroll_offset + page_step).clamp(0, max_scroll)
          @auto_scroll = true if @scroll_offset >= max_scroll
          true
        when "home"
          scroll_to_top
          @auto_scroll = false
          true
        when "end"
          scroll_to_end
          @auto_scroll = true
          true
        else
          false
        end
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        vl = visible_lines
        max_scroll = Math.max(0, vl.size - @last_h)

        case event.button
        when Terminal::MouseButton::WheelUp
          @auto_scroll = false
          @scroll_offset = (@scroll_offset - 2).clamp(0, max_scroll)
          true
        when Terminal::MouseButton::WheelDown
          @scroll_offset = (@scroll_offset + 2).clamp(0, max_scroll)
          @auto_scroll = true if @scroll_offset >= max_scroll
          true
        else
          false
        end
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        {available_w, Math.min(available_h, 20)}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0

        @last_x = x
        @last_y = y
        @last_w = width
        @last_h = height

        th = current_theme
        c_bg = @bg || Color.none
        c_fg = @text_fg || th.text
        c_track = th.border
        c_thumb = @scrollbar_thumb_fg || (focused? ? th.primary : th.accent)

        vl = visible_lines
        total_lines = vl.size
        max_scroll = Math.max(0, total_lines - height)

        actual_scroll = @scroll_offset.clamp(0, max_scroll)

        # Content width accounts for 1-column scrollbar if overflow occurs
        has_scrollbar = total_lines > height
        content_w = has_scrollbar ? Math.max(0, width - 1) : width

        # Render visible rows
        (0...height).each do |row_idx|
          target_y = y + row_idx
          line_idx = actual_scroll + row_idx

          if line_idx < total_lines
            line_str = vl[line_idx]
            buffer.put_string(x, target_y, line_str, fg: c_fg, bg: c_bg, max_width: content_w)
          else
            # Empty row
            buffer.put_string(x, target_y, " " * content_w, bg: c_bg, max_width: content_w)
          end
        end

        # Render Right Scrollbar if lines exceed height
        if has_scrollbar && width > 1
          sb_x = x + width - 1
          thumb_h = Math.max(1, ((height.to_f / total_lines.to_f) * height).round.to_i)
          thumb_pos = if max_scroll > 0
                        ((actual_scroll.to_f / max_scroll.to_f) * (height - thumb_h)).round.to_i
                      else
                        0
                      end

          (0...height).each do |sy|
            target_y = y + sy
            is_thumb = sy >= thumb_pos && sy < thumb_pos + thumb_h
            char = is_thumb ? '█' : '│'
            fg_color = is_thumb ? c_thumb : c_track
            buffer.put_char(sb_x, target_y, char, fg: fg_color)
          end
        end
      end
    end
  end
end
