require "../element"
require "../../style/border"
require "../../style/color"
require "../../style/visual_width"

module Opal
  module UI
    # Container component providing border, padding, and an optional embedded title.
    class Box < Element
      property child : Element?
      property border : Border?
      property border_fg : Color?
      property padding_top : Int32
      property padding_right : Int32
      property padding_bottom : Int32
      property padding_left : Int32
      property title : String?
      property title_fg : Color?
      property bg : Color

      def initialize(
        @child : Element? = nil,
        border : Symbol | Border | String | Nil = nil,
        border_fg : Color | Symbol | String | Nil = nil,
        padding : Int32 = 0,
        @title : String? = nil,
        title_fg : Color | Symbol | String | Nil = nil,
        bg : Color | Symbol | String = Color.none,
      )
        @border = border ? Border.from(border) : nil
        @border_fg = border_fg ? Color.from(border_fg) : nil
        @title_fg = title_fg ? Color.from(title_fg) : nil
        @bg = Color.from(bg)
        @padding_top = @padding_right = @padding_bottom = @padding_left = padding
      end

      def children : Array(Element)
        if c = @child
          [c]
        else
          [] of Element
        end
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        eff_border = @border || current_theme.box_border
        border_x = eff_border.active? ? 2 : 0
        border_y = eff_border.active? ? 2 : 0

        inner_avail_w = Math.max(0, available_w - border_x - @padding_left - @padding_right)
        inner_avail_h = Math.max(0, available_h - border_y - @padding_top - @padding_bottom)

        child_w, child_h = @child.try(&.preferred_size(inner_avail_w, inner_avail_h)) || {0, 0}

        title_w = @title ? VisualWidth.width(@title.not_nil!) + 4 : 0
        total_w = Math.max(child_w + border_x + @padding_left + @padding_right, title_w + border_x)
        total_h = child_h + border_y + @padding_top + @padding_bottom

        {Math.min(total_w, available_w), Math.min(total_h, available_h)}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0

        # Fill solid background if specified
        if @bg.type != Color::Type::None
          buffer.fill(x, y, width, height, ' ', Color.none, @bg)
        end

        eff_border = @border || current_theme.box_border
        eff_border_fg = @border_fg || current_theme.border
        eff_title_fg = @title_fg || current_theme.accent

        if eff_border.active?
          render_border(buffer, x, y, width, height, eff_border, eff_border_fg, eff_title_fg)
        end

        border_offset_x = eff_border.active? ? 1 : 0
        border_offset_y = eff_border.active? ? 1 : 0

        inner_x = x + border_offset_x + @padding_left
        inner_y = y + border_offset_y + @padding_top
        inner_w = Math.max(0, width - (border_offset_x * 2) - @padding_left - @padding_right)
        inner_h = Math.max(0, height - (border_offset_y * 2) - @padding_top - @padding_bottom)

        @child.try(&.render(buffer, inner_x, inner_y, inner_w, inner_h))
      end

      private def render_border(
        buffer : Buffer,
        x : Int32,
        y : Int32,
        width : Int32,
        height : Int32,
        b : Border,
        border_c : Color,
        title_c : Color,
      ) : Nil
        return if width < 2 || height < 2

        # Corners
        buffer.put_string(x, y, b.top_left, fg: border_c, bg: @bg) if !b.top_left.empty?
        buffer.put_string(x + width - 1, y, b.top_right, fg: border_c, bg: @bg) if !b.top_right.empty?
        buffer.put_string(x, y + height - 1, b.bottom_left, fg: border_c, bg: @bg) if !b.bottom_left.empty?
        buffer.put_string(x + width - 1, y + height - 1, b.bottom_right, fg: border_c, bg: @bg) if !b.bottom_right.empty?

        # Horizontal top and bottom edges (with pattern support)
        buffer.put_string(x + 1, y, b.top_segment(width - 2), fg: border_c, bg: @bg)
        buffer.put_string(x + 1, y + height - 1, b.bottom_segment(width - 2), fg: border_c, bg: @bg)

        # Embedded title in top border with safe truncation
        if t = @title
          avail = Math.max(0, width - 4)
          if avail > 0
            disp_title = if VisualWidth.width(t) + 2 <= avail
                           " #{t} "
                         elsif avail > 2
                           " #{truncate_text(t, avail - 2)} "
                         else
                           truncate_text(t, avail)
                         end
            buffer.put_string(x + 2, y, disp_title, fg: title_c, bg: @bg, bold: true, max_width: avail)
          end
        end

        # Vertical left and right edges (with pattern support)
        (1...(height - 1)).each do |row|
          buffer.put_char(x, y + row, b.left_char(row - 1), fg: border_c, bg: @bg)
          buffer.put_char(x + width - 1, y + row, b.right_char(row - 1), fg: border_c, bg: @bg)
        end
      end

      private def truncate_text(text : String, max_w : Int32) : String
        return "" if max_w <= 0
        return text if VisualWidth.width(text) <= max_w
        return "…" if max_w == 1

        avail = max_w - 1
        res = IO::Memory.new
        cur_w = 0
        text.each_char do |ch|
          cw = VisualWidth.char_width(ch)
          break if cur_w + cw > avail
          res << ch
          cur_w += cw
        end
        res << "…"
        res.to_s
      end
    end
  end
end
