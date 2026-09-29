require "../element"
require "../../style/border"
require "../../style/color"
require "../../style/visual_width"

module Opal
  module UI
    # Container component providing border, padding, and an optional embedded title.
    class Box < Element
      property child : Element?
      property border : Border
      property border_fg : Color
      property padding_top : Int32
      property padding_right : Int32
      property padding_bottom : Int32
      property padding_left : Int32
      property title : String?
      property title_fg : Color

      def initialize(
        @child : Element? = nil,
        border : Symbol | Border = :rounded,
        border_fg : Color | Symbol | String = Color.none,
        padding : Int32 = 0,
        @title : String? = nil,
        title_fg : Color | Symbol | String = :cyan,
      )
        @border = Border.from(border)
        @border_fg = Color.from(border_fg)
        @title_fg = Color.from(title_fg)
        @padding_top = @padding_right = @padding_bottom = @padding_left = padding
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        border_x = @border.active? ? 2 : 0
        border_y = @border.active? ? 2 : 0

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

        if @border.active?
          render_border(buffer, x, y, width, height)
        end

        border_offset_x = @border.active? ? 1 : 0
        border_offset_y = @border.active? ? 1 : 0

        inner_x = x + border_offset_x + @padding_left
        inner_y = y + border_offset_y + @padding_top
        inner_w = Math.max(0, width - (border_offset_x * 2) - @padding_left - @padding_right)
        inner_h = Math.max(0, height - (border_offset_y * 2) - @padding_top - @padding_bottom)

        @child.try(&.render(buffer, inner_x, inner_y, inner_w, inner_h))
      end

      private def render_border(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width < 2 || height < 2

        # Corners
        buffer.put_char(x, y, @border.top_left[0], fg: @border_fg) if !@border.top_left.empty?
        buffer.put_char(x + width - 1, y, @border.top_right[0], fg: @border_fg) if !@border.top_right.empty?
        buffer.put_char(x, y + height - 1, @border.bottom_left[0], fg: @border_fg) if !@border.bottom_left.empty?
        buffer.put_char(x + width - 1, y + height - 1, @border.bottom_right[0], fg: @border_fg) if !@border.bottom_right.empty?

        # Horizontal top and bottom edges
        top_char = @border.top.empty? ? ' ' : @border.top[0]
        bot_char = @border.bottom.empty? ? ' ' : @border.bottom[0]

        ((x + 1)...(x + width - 1)).each do |cur_x|
          buffer.put_char(cur_x, y, top_char, fg: @border_fg)
          buffer.put_char(cur_x, y + height - 1, bot_char, fg: @border_fg)
        end

        # Embedded title in top border
        if t = @title
          clean_title = " #{t} "
          title_len = VisualWidth.width(clean_title)
          if title_len < width - 4
            buffer.put_string(x + 2, y, clean_title, fg: @title_fg, bold: true)
          end
        end

        # Vertical left and right edges
        left_char = @border.left.empty? ? ' ' : @border.left[0]
        right_char = @border.right.empty? ? ' ' : @border.right[0]

        ((y + 1)...(y + height - 1)).each do |cur_y|
          buffer.put_char(x, cur_y, left_char, fg: @border_fg)
          buffer.put_char(x + width - 1, cur_y, right_char, fg: @border_fg)
        end
      end
    end
  end
end
