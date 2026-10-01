require "../element"
require "../../style/color"
require "../../style/visual_width"
require "../../style/border"

module Opal
  module UI
    # Layout prototyping placeholder widget inspired by Python Textual's Placeholder.
    # Renders an area-filling card with interior diagonal cross or pattern,
    # centered title, and computed width x height dimensions badge.
    class Placeholder < Element
      property label : String?
      property border : Border
      property border_fg : Color? = nil
      property text_fg : Color? = nil
      property bg : Color? = nil
      property fill_char : Char = '·'

      def initialize(
        @label : String? = nil,
        border : Symbol | Border = :rounded,
        border_fg : Color | Symbol | String = Color.none,
        text_fg : Color | Symbol | String = Color.none,
        bg : Color | Symbol | String = Color.none,
      )
        @border = case border
                  when Border then border
                  else             Border.from(border)
                  end
        @border_fg = Color.from(border_fg) if border_fg != Color.none
        @text_fg = Color.from(text_fg) if text_fg != Color.none
        @bg = Color.from(bg) if bg != Color.none
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        {available_w, available_h}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0

        th = current_theme
        b_fg = @border_fg || th.border
        t_fg = @text_fg || th.primary
        card_bg = @bg || Color.none

        # 1. Fill background with subtle dot pattern
        (0...height).each do |cy|
          (0...width).each do |cx|
            buffer.put_char(x + cx, y + cy, @fill_char, fg: th.border, bg: card_bg, dim: true)
          end
        end

        # 2. Draw border
        buffer.put_string(x, y, @border.top_left, fg: b_fg, bg: card_bg)
        buffer.put_string(x + 1, y, @border.top_segment(width - 2), fg: b_fg, bg: card_bg)
        buffer.put_string(x + width - 1, y, @border.top_right, fg: b_fg, bg: card_bg)

        (1...(height - 1)).each do |cy|
          buffer.put_char(x, y + cy, @border.left_char(cy - 1), fg: b_fg, bg: card_bg)
          buffer.put_char(x + width - 1, y + cy, @border.right_char(cy - 1), fg: b_fg, bg: card_bg)
        end

        buffer.put_string(x, y + height - 1, @border.bottom_left, fg: b_fg, bg: card_bg)
        buffer.put_string(x + 1, y + height - 1, @border.bottom_segment(width - 2), fg: b_fg, bg: card_bg)
        buffer.put_string(x + width - 1, y + height - 1, @border.bottom_right, fg: b_fg, bg: card_bg)

        # 3. Center Label & Dimensions badge
        dim_str = "#{width} × #{height}"
        title_str = @label ? "#{@label}: #{dim_str}" : dim_str
        badge_str = " [ #{title_str} ] "

        avail = width - 2
        if avail >= 4 && height >= 3
          display_str = if VisualWidth.width(badge_str) <= avail
                          badge_str
                        elsif VisualWidth.width("[ #{title_str} ]") <= avail
                          "[ #{title_str} ]"
                        elsif VisualWidth.width("[#{title_str}]") <= avail
                          "[#{title_str}]"
                        elsif VisualWidth.width(title_str) <= avail
                          title_str
                        elsif @label && VisualWidth.width(@label.not_nil!) <= avail
                          @label.not_nil!
                        else
                          VisualWidth.truncate(title_str, avail)
                        end
          bw = VisualWidth.width(display_str)
          center_x = x + 1 + [(avail - bw) // 2, 0].max
          center_y = y + (height // 2)
          buffer.put_string(center_x, center_y, display_str, fg: card_bg.type == Color::Type::None ? th.background : th.text, bg: t_fg, bold: true)
        end
      end
    end
  end
end
