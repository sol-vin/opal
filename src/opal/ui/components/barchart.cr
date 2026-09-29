require "../element"
require "../buffer"
require "../../style/color"
require "../../style/visual_width"

module Opal
  module UI
    # Represents a single bar item in a BarChart
    struct BarItem
      getter label : String
      getter value : Float64
      getter color : Color
      getter formatted_value : String?

      def initialize(
        @label : String,
        @value : Float64,
        color : Color | Symbol | String = :cyan,
        @formatted_value : String? = nil,
      )
        @color = Color.from(color)
      end
    end

    # Renders horizontal bar charts with labels, percentage scaling, and values.
    class BarChart < Element
      getter title : String?
      getter items : Array(BarItem)
      getter bar_char : Char
      getter max_value : Float64?

      def initialize(
        @items : Array(BarItem) = [] of BarItem,
        @title : String? = nil,
        @bar_char : Char = '█',
        @max_value : Float64? = nil,
      )
      end

      def add(label : String, value : Float64, color : Color | Symbol | String = :cyan, formatted_value : String? = nil) : Nil
        @items << BarItem.new(label, value, color, formatted_value)
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        h = @items.size + (@title ? 2 : 0)
        {available_w, [h, available_h].min}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if @items.empty?

        cur_y = y
        if t = @title
          buffer.put_string(x, cur_y, t, fg: Color.cyan, bold: true, max_width: width)
          cur_y += 1
          buffer.put_string(x, cur_y, "─" * Math.min(width, VisualWidth.width(t) + 4), fg: Color.bright_black)
          cur_y += 1
        end

        max_val = @max_value || (@items.map(&.value).max? || 1.0)
        max_val = 1.0 if max_val <= 0.0

        max_label_w = @items.map { |i| VisualWidth.width(i.label) }.max? || 0
        val_w = 8 # Room for value text

        available_bar_w = Math.max(1, width - max_label_w - val_w - 4)

        @items.each do |item|
          break if cur_y >= y + height

          # Draw label
          buffer.put_string(x, cur_y, item.label.rjust(max_label_w), fg: Color.white)
          buffer.put_string(x + max_label_w, cur_y, " ▏", fg: Color.bright_black)

          # Draw bar
          ratio = (item.value / max_val).clamp(0.0, 1.0)
          bar_len = (ratio * available_bar_w).round.to_i
          if bar_len > 0
            bar_str = @bar_char.to_s * bar_len
            buffer.put_string(x + max_label_w + 2, cur_y, bar_str, fg: item.color)
          end

          # Draw value
          val_str = item.formatted_value || (item.value == item.value.to_i ? item.value.to_i.to_s : sprintf("%.1f", item.value))
          buffer.put_string(x + max_label_w + 3 + bar_len, cur_y, val_str, fg: Color.bright_black)

          cur_y += 1
        end
      end
    end
  end
end
