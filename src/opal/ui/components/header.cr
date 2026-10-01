require "../element"
require "../../style/color"
require "../../style/visual_width"

module Opal
  module UI
    # Standardized application top header inspired by Python Textual's Header.
    # Displays app title, optional subtitle/screen mode badge, and a real-time clock.
    class Header < Element
      property title : String
      property subtitle : String?
      property icon : String?
      property? show_clock : Bool = true

      # Styling
      property bg : Color? = nil
      property title_fg : Color? = nil
      property subtitle_fg : Color? = nil
      property clock_fg : Color? = nil

      def initialize(
        @title : String = "Opal Application",
        @subtitle : String? = nil,
        @icon : String? = "[*]",
        @show_clock : Bool = true,
      )
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        {available_w, 1}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0

        th = current_theme
        header_bg = @bg || th.surface
        header_title_fg = @title_fg || th.primary
        header_sub_fg = @subtitle_fg || th.accent
        header_clock_fg = @clock_fg || th.text_muted

        # Fill background
        buffer.fill(x, y, width, 1, UI::Cell.new(' ', fg: Color.none, bg: header_bg))

        # 1. Left Title & Icon
        cur_x = x + 1
        if ic = @icon
          buffer.put_string(cur_x, y, ic, fg: th.accent, bg: header_bg, bold: true)
          cur_x += VisualWidth.width(ic) + 1
        end

        buffer.put_string(cur_x, y, @title, fg: header_title_fg, bg: header_bg, bold: true, max_width: width - cur_x)
        cur_x += VisualWidth.width(@title) + 1

        # 2. Subtitle / Badge
        if sub = @subtitle
          if cur_x + VisualWidth.width(sub) + 4 < x + width - 12
            badge_text = " [#{sub}] "
            buffer.put_string(cur_x, y, badge_text, fg: th.background, bg: header_sub_fg, bold: true)
          end
        end

        # 3. Right Clock
        if @show_clock
          now_str = Time.local.to_s("%H:%M:%S")
          clock_w = now_str.size
          clock_x = x + width - clock_w - 2
          if clock_x > cur_x + 2
            buffer.put_string(clock_x, y, now_str, fg: header_clock_fg, bg: header_bg, bold: true)
          end
        end
      end
    end
  end
end
