require "../element"
require "../../style/color"
require "../../style/visual_width"

module Opal
  module UI
    # Scrollable viewport element displaying a subset of content with an optional scroll indicator.
    class Viewport < Element
      property content : String
      property offset_y : Int32
      property fg : Color
      property? show_scrollbar : Bool

      def initialize(
        @content : String = "",
        @offset_y : Int32 = 0,
        fg : Color | Symbol | String = Color.none,
        @show_scrollbar : Bool = true,
      )
        @fg = Color.from(fg)
      end

      def scroll_up(lines : Int32 = 1) : Nil
        @offset_y = Math.max(0, @offset_y - lines)
      end

      def scroll_down(lines : Int32 = 1) : Nil
        total_lines = @content.split('\n').size
        @offset_y = Math.min(Math.max(0, total_lines - 1), @offset_y + lines)
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        lines = @content.split('\n')
        max_w = lines.map { |l| VisualWidth.width(l) }.max? || 0
        {Math.min(max_w, available_w), available_h}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0

        all_lines = @content.split('\n')
        visible_lines = all_lines[@offset_y...@offset_y + height]? || [] of String

        content_w = @show_scrollbar ? Math.max(1, width - 1) : width

        visible_lines.each_with_index do |line, row_idx|
          buffer.put_string(x, y + row_idx, line, fg: @fg, max_width: content_w)
        end

        # Draw scrollbar track if content exceeds viewport height
        if @show_scrollbar && all_lines.size > height
          track_x = x + width - 1
          thumb_pos = ((@offset_y.to_f / (all_lines.size - height)) * (height - 1)).round.to_i.clamp(0, height - 1)

          (0...height).each do |row_idx|
            char = (row_idx == thumb_pos) ? '█' : '│'
            buffer.put_char(track_x, y + row_idx, char, dim: row_idx != thumb_pos)
          end
        end
      end
    end
  end
end
