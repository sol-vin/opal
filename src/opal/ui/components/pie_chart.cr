require "../element"
require "../buffer"
require "../../style/color"
require "../../style/visual_width"

module Opal
  module UI
    # Represents a single slice of data in a PieChart.
    struct PieSlice
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

    # Renders interactive 2D circular or donut PieCharts with slices,
    # percentage breakdowns, TrueColor fills, and legend keys.
    class PieChart < Element
      getter title : String?
      getter slices : Array(PieSlice)
      property? donut : Bool
      property inner_radius_ratio : Float64

      def initialize(
        @slices : Array(PieSlice) = [] of PieSlice,
        @title : String? = nil,
        @donut : Bool = false,
        @inner_radius_ratio : Float64 = 0.42,
      )
      end

      def add(label : String, value : Float64, color : Color | Symbol | String = :cyan, formatted_value : String? = nil) : Nil
        return if value <= 0.0
        @slices << PieSlice.new(label, value, color, formatted_value)
      end

      def total_value : Float64
        @slices.map(&.value).sum
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        h = Math.max(10, Math.min(available_h, 18))
        w = Math.max(30, Math.min(available_w, 70))
        {w, h}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if @slices.empty? || width < 20 || height < 6

        cur_y = y
        if t = @title
          buffer.put_string(x, cur_y, t, fg: Color.cyan, bold: true, max_width: width)
          cur_y += 1
          buffer.put_string(x, cur_y, "─" * Math.min(width, VisualWidth.width(t) + 4), fg: Color.bright_black)
          cur_y += 1
        end

        total = total_value
        return if total <= 0.0

        chart_h = (height - (cur_y - y)).clamp(6, 20)
        # Pie radius in character cells (height-based)
        radius = (chart_h.to_f * 0.44).clamp(3.0, 10.0)
        inner_r = @donut ? radius * @inner_radius_ratio : 0.0

        pie_diameter_cols = (radius * 2.0 * 2.0).round.to_i + 2 # 2:1 aspect ratio
        center_x = x + (pie_diameter_cols // 2)
        center_y = cur_y + (chart_h // 2)

        # Precompute angular slice ranges [start_angle, end_angle)
        # Angles normalized to 0 .. 2*PI, starting from top (-PI/2)
        slice_ranges = [] of {Float64, Float64, PieSlice, Float64}
        accum_angle = -Math::PI / 2.0

        @slices.each do |slice|
          pct = slice.value / total
          sweep = pct * 2.0 * Math::PI
          start_ang = accum_angle
          end_ang = accum_angle + sweep
          slice_ranges << {start_ang, end_ang, slice, pct * 100.0}
          accum_angle = end_ang
        end

        # Rasterize circle pixels into buffer
        (-chart_h // 2..chart_h // 2).each do |dy|
          sy = center_y + dy
          next if sy < cur_y || sy >= y + height

          (-pie_diameter_cols // 2..pie_diameter_cols // 2).each do |dx|
            sx = center_x + dx
            next if sx < x || sx >= x + width

            # Aspect ratio compensation (terminal characters are ~2:1 height:width)
            nx = dx.to_f / 2.0
            ny = dy.to_f
            dist = Math.sqrt(nx * nx + ny * ny)

            if dist > radius
              next
            end

            if @donut && dist < inner_r
              buffer.put_char(sx, sy, ' ')
              next
            end

            # Angle from center in [-PI, PI]
            angle = Math.atan2(ny, nx)
            # Normalize angle relative to -PI/2 starting point
            norm_angle = angle
            norm_angle += 2.0 * Math::PI if norm_angle < -Math::PI / 2.0
            if norm_angle >= (3.0 * Math::PI / 2.0)
              norm_angle -= 2.0 * Math::PI
            end

            # Find matching slice
            matched_slice : PieSlice? = nil
            slice_ranges.each do |s_start, s_end, s_item, _pct|
              if norm_angle >= s_start && norm_angle <= s_end
                matched_slice = s_item
                break
              end
            end

            matched_slice ||= slice_ranges.last[2]

            buffer.put_char(sx, sy, '█', fg: matched_slice.color)
          end
        end

        # Draw Center Label for Donut Charts
        if @donut
          tot_str = sprintf("%.0f", total)
          tot_x = center_x - (tot_str.size // 2)
          buffer.put_string(tot_x, center_y, tot_str, fg: Color.bright_white, bold: true)
        end

        # Draw Legend Panel to the right of the Pie
        legend_x = center_x + (pie_diameter_cols // 2) + 3
        legend_w = (x + width) - legend_x
        return if legend_w < 12

        l_y = cur_y + 1
        buffer.put_string(legend_x, l_y, "Distribution:", fg: Color.white, bold: true)
        l_y += 1

        slice_ranges.each do |_, _, slice, pct|
          break if l_y >= y + height

          # Color swatch
          buffer.put_char(legend_x, l_y, '■', fg: slice.color)

          # Label + percentage
          pct_str = sprintf("%4.1f%%", pct)
          val_str = slice.formatted_value || sprintf("%.1f", slice.value)
          line_text = " #{slice.label} : #{val_str} (#{pct_str})"

          buffer.put_string(legend_x + 2, l_y, line_text, fg: Color.white, max_width: legend_w - 2)
          l_y += 1
        end
      end

      # Class convenience method returning styled pie chart string
      def self.to_string(
        slices : Array(PieSlice),
        title : String? = nil,
        donut : Bool = false,
        width : Int32? = nil,
        height : Int32 = 12,
        inner_radius_ratio : Float64 = 0.42,
        color : Bool? = nil,
        theme : Theme? = nil,
      ) : String
        pc = PieChart.new(slices: slices, title: title, donut: donut, inner_radius_ratio: inner_radius_ratio)
        term_width = (Terminal::Info.new.width rescue 80)
        w = width || term_width
        buffer = Buffer.new(w, height)
        pc.render(buffer, 0, 0, w, height)

        use_color = if color.nil?
                      (STDOUT.tty? rescue false) && !ENV.has_key?("NO_COLOR")
                    else
                      color
                    end
        buffer.render_to_string(with_ansi: use_color)
      end

      # Class convenience method printing styled pie chart directly to IO
      def self.print(
        slices : Array(PieSlice),
        title : String? = nil,
        donut : Bool = false,
        io : IO = STDOUT,
        width : Int32? = nil,
        height : Int32 = 12,
        inner_radius_ratio : Float64 = 0.42,
        color : Bool? = nil,
        theme : Theme? = nil,
      ) : Nil
        io.print to_string(
          slices: slices,
          title: title,
          donut: donut,
          width: width,
          height: height,
          inner_radius_ratio: inner_radius_ratio,
          color: color,
          theme: theme
        )
      end

      # Overload accepting tuples of {label, value}
      def self.to_string(
        raw_slices : Array(Tuple(String, Float64)),
        title : String? = nil,
        donut : Bool = false,
        width : Int32? = nil,
        height : Int32 = 12,
        inner_radius_ratio : Float64 = 0.42,
        color : Bool? = nil,
        theme : Theme? = nil,
      ) : String
        slices = raw_slices.map { |lbl, val| PieSlice.new(lbl, val) }
        to_string(
          slices: slices,
          title: title,
          donut: donut,
          width: width,
          height: height,
          inner_radius_ratio: inner_radius_ratio,
          color: color,
          theme: theme
        )
      end

      # Overload printing tuples of {label, value} directly to IO
      def self.print(
        raw_slices : Array(Tuple(String, Float64)),
        title : String? = nil,
        donut : Bool = false,
        io : IO = STDOUT,
        width : Int32? = nil,
        height : Int32 = 12,
        inner_radius_ratio : Float64 = 0.42,
        color : Bool? = nil,
        theme : Theme? = nil,
      ) : Nil
        slices = raw_slices.map { |lbl, val| PieSlice.new(lbl, val) }
        print(
          slices: slices,
          title: title,
          donut: donut,
          io: io,
          width: width,
          height: height,
          inner_radius_ratio: inner_radius_ratio,
          color: color,
          theme: theme
        )
      end
    end
  end
end
