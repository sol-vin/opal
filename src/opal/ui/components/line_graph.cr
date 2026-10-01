require "../element"
require "../buffer"
require "../../style/color"
require "../../style/visual_width"

module Opal
  module UI
    # Represents a single data series in a LineGraph
    class LineSeries
      property name : String
      property data : Array(Float64)
      property color : Color

      def initialize(
        @name : String,
        @data : Array(Float64) = [] of Float64,
        color : Color | Symbol | String = :cyan,
      )
        @color = Color.from(color)
      end

      def push(val : Float64) : Nil
        @data << val
      end
    end

    # Renders 2D Cartesian line graphs and multi-series plots with axes,
    # labels, tick marks, and smooth connected curves.
    class LineGraph < Element
      getter title : String?
      getter series : Array(LineSeries)
      property min_y : Float64?
      property max_y : Float64?
      property? show_grid : Bool = true
      property? show_legend : Bool = true

      def initialize(
        @series : Array(LineSeries) = [] of LineSeries,
        @title : String? = nil,
        @min_y : Float64? = nil,
        @max_y : Float64? = nil,
        @show_grid : Bool = true,
        @show_legend : Bool = true,
      )
      end

      def add_series(name : String, data : Array(Float64), color : Color | Symbol | String = :cyan) : LineSeries
        s = LineSeries.new(name, data, color)
        @series << s
        s
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        {Math.max(30, Math.min(available_w, 80)), Math.max(10, Math.min(available_h, 20))}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if @series.empty? || width < 25 || height < 7

        cur_y = y

        # 1. Title
        if t = @title
          buffer.put_string(x, cur_y, t, fg: Color.cyan, bold: true, max_width: width)
          cur_y += 1
          buffer.put_string(x, cur_y, "─" * Math.min(width, VisualWidth.width(t) + 4), fg: Color.bright_black)
          cur_y += 1
        end

        # 2. Legend
        if @show_legend
          leg_x = x + 1
          @series.each do |s|
            break if leg_x + VisualWidth.width(s.name) + 6 >= x + width
            buffer.put_string(leg_x, cur_y, "──", fg: s.color, bold: true)
            buffer.put_char(leg_x + 2, cur_y, '●', fg: s.color)
            buffer.put_string(leg_x + 4, cur_y, s.name, fg: Color.white)
            leg_x += VisualWidth.width(s.name) + 6
          end
          cur_y += 1
        end

        # Calculate data value range without heap allocations
        has_vals = false
        min_v = Float64::MAX
        max_v = -Float64::MAX
        @series.each do |s|
          s.data.each do |v|
            has_vals = true
            min_v = v if v < min_v
            max_v = v if v > max_v
          end
        end
        return unless has_vals

        min_val = @min_y || min_v
        max_val = @max_y || max_v
        max_val = min_val + 1.0 if (max_val - min_val).abs < 1e-6

        # Layout graph grid
        gutter_w = 6 # e.g. " 100 ┤"
        axis_x = x + gutter_w
        graph_w = Math.max(10, width - gutter_w - 2)
        graph_h = Math.max(4, height - (cur_y - y) - 2)
        bottom_y = cur_y + graph_h - 1

        # 3. Y-Axis Ticks and Gridlines
        # Top tick (max)
        top_str = sprintf("%4.0f", max_val)
        buffer.put_string(x, cur_y, top_str, fg: Color.bright_black)
        buffer.put_char(axis_x, cur_y, '┐', fg: Color.bright_black)

        # Mid tick
        mid_val = (min_val + max_val) / 2.0
        mid_y = cur_y + (graph_h // 2)
        mid_str = sprintf("%4.0f", mid_val)
        buffer.put_string(x, mid_y, mid_str, fg: Color.bright_black)
        buffer.put_char(axis_x, mid_y, '┼', fg: Color.bright_black)

        # Bottom tick (min)
        bot_str = sprintf("%4.0f", min_val)
        buffer.put_string(x, bottom_y, bot_str, fg: Color.bright_black)
        buffer.put_char(axis_x, bottom_y, '└', fg: Color.bright_black)

        # Vertical axis line & grid
        (cur_y..bottom_y).each do |gy|
          if gy != cur_y && gy != mid_y && gy != bottom_y
            buffer.put_char(axis_x, gy, '│', fg: Color.bright_black)
          end

          if @show_grid && (gy == mid_y || gy == cur_y)
            grid_char = gy == cur_y ? '┄' : '┄'
            buffer.put_string(axis_x + 1, gy, grid_char.to_s * graph_w, fg: Color.bright_black)
          end
        end

        # Horizontal bottom axis line
        buffer.put_string(axis_x + 1, bottom_y, "─" * graph_w, fg: Color.bright_black)

        # 4. Plot Series Lines
        @series.each do |s|
          data = s.data
          next if data.empty?

          plot_w = graph_w
          # Sample or map points across graph_w
          pts = Array({Int32, Int32}).new(data.size)
          data.each_with_index do |val, d_idx|
            break if d_idx >= plot_w

            col_x = axis_x + 1 + d_idx
            ratio = ((val - min_val) / (max_val - min_val)).clamp(0.0, 1.0)
            row_y = bottom_y - (ratio * (graph_h - 1)).round.to_i
            pts << {col_x, row_y}
          end

          # Draw connecting segments and data markers
          (0...pts.size).each do |p_idx|
            cx1, cy1 = pts[p_idx]
            buffer.put_char(cx1, cy1, '●', fg: s.color)

            if p_idx + 1 < pts.size
              cx2, cy2 = pts[p_idx + 1]
              # If next point is adjacent
              if cx2 == cx1 + 1
                if cy2 == cy1
                  # Horizontal connection: do nothing or bridge
                elsif cy2 < cy1 # Going up
                  mid_y_step = cy1 - 1
                  while mid_y_step > cy2
                    buffer.put_char(cx1, mid_y_step, '│', fg: s.color)
                    mid_y_step -= 1
                  end
                elsif cy2 > cy1 # Going down
                  mid_y_step = cy1 + 1
                  while mid_y_step < cy2
                    buffer.put_char(cx1, mid_y_step, '│', fg: s.color)
                    mid_y_step += 1
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
