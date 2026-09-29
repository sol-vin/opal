require "../element"
require "../buffer"
require "../../style/color"
require "../../style/visual_width"

module Opal
  module UI
    # Unicode block sparkline generator for visualizing numeric trends.
    class Sparkline < Element
      BLOCKS = [' ', '▂', '▃', '▄', '▅', '▆', '▇', '█']

      getter data : Array(Float64)
      getter color : Color
      getter title : String?
      getter min : Float64?
      getter max : Float64?

      def initialize(
        @data : Array(Float64),
        color : Color | Symbol | String = :cyan,
        @title : String? = nil,
        @min : Float64? = nil,
        @max : Float64? = nil,
      )
        @color = Color.from(color)
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        w = [@data.size, (@title ? VisualWidth.width(@title.not_nil!) : 0)].max
        h = @title ? 2 : 1
        {[w, available_w].min, [h, available_h].min}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if @data.empty?

        cur_y = y
        if t = @title
          buffer.put_string(x, cur_y, t, fg: @color, bold: true, max_width: width)
          cur_y += 1
          return if cur_y >= y + height
        end

        data_min = @min || (@data.min? || 0.0)
        data_max = @max || (@data.max? || 1.0)
        span = data_max - data_min
        span = 1.0 if span <= 0.0

        visible_count = Math.min(@data.size, width)
        # Take the most recent values if data exceeds width
        start_idx = @data.size - visible_count

        visible_count.times do |i|
          val = @data[start_idx + i]
          ratio = ((val - data_min) / span).clamp(0.0, 1.0)
          block_idx = (ratio * (BLOCKS.size - 1)).round.to_i
          char = BLOCKS[block_idx]

          buffer.put_char(x + i, cur_y, char, fg: @color)
        end
      end

      # Convenience helper returning sparkline as a string
      def self.render_to_string(data : Array(Float64), color : Color | Symbol | String = Color.none) : String
        return "" if data.empty?
        data_min = data.min? || 0.0
        data_max = data.max? || 1.0
        span = data_max - data_min
        span = 1.0 if span <= 0.0

        c = Color.from(color)
        String.build do |io|
          io << c.fg_escape
          data.each do |val|
            ratio = ((val - data_min) / span).clamp(0.0, 1.0)
            block_idx = (ratio * (BLOCKS.size - 1)).round.to_i
            io << BLOCKS[block_idx]
          end
          io << "\e[0m" if c.type != Color::Type::None
        end
      end
    end
  end
end
