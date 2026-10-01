require "../element"
require "../buffer"
require "../../style/color"
require "../../style/glyphs"

module Opal
  module UI
    enum MeterOrientation
      Horizontal
      Vertical
    end

    enum MeterGradient
      Heat  # Green -> Yellow -> Red
      Cool  # Blue -> Cyan -> Green
      Neon  # Purple -> Magenta -> Cyan
      Solid # Single solid theme color
    end

    # High-density progress and telemetry meter utilizing 1/8th Unicode fractional
    # block characters for ultra-precise terminal data visualization.
    class Meter < Element
      property value : Float64 # Normalized 0.0 to 1.0
      property orientation : MeterOrientation = MeterOrientation::Horizontal
      property gradient : MeterGradient = MeterGradient::Heat
      property solid_color : Color = Color.hex("#38ef7d")
      property? show_label : Bool = true
      property label_format : String = "%.1f%%"

      def initialize(
        @value : Float64 = 0.0,
        @orientation : MeterOrientation = MeterOrientation::Horizontal,
        @gradient : MeterGradient = MeterGradient::Heat,
        @show_label : Bool = true,
        width : Int32? = nil,
        height : Int32? = nil,
      )
        w = width || (@orientation == MeterOrientation::Horizontal ? 20 : 1)
        h = height || (@orientation == MeterOrientation::Horizontal ? 1 : 10)
        super()
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        if @orientation == MeterOrientation::Horizontal
          {Math.min(available_w, 20), 1}
        else
          {1, Math.min(available_h, 10)}
        end
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0
        val = @value.clamp(0.0, 1.0)

        if @orientation == MeterOrientation::Horizontal
          render_horizontal(buffer, x, y, width, height, val)
        else
          render_vertical(buffer, x, y, width, height, val)
        end
      end

      private def render_horizontal(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32, val : Float64) : Nil
        label_str = @show_label ? sprintf(" " + @label_format, val * 100.0) : ""
        bar_w = Math.max(1, width - label_str.size)

        # Total eighths across the entire bar width
        total_eighths = (val * bar_w * 8.0).round.to_i

        (0...bar_w).each do |col|
          cell_eighths = (total_eighths - (col * 8)).clamp(0, 8)
          glyph = Glyphs::HorizontalBlocks[cell_eighths]

          pos_ratio = col.to_f / bar_w.to_f
          fg_color = resolve_color(pos_ratio, val)

          buffer.put_char(x + col, y, glyph, fg: fg_color, bg: Color.hex("#1e293b"))
        end

        # Draw label
        if !label_str.empty?
          buffer.put_string(x + bar_w, y, label_str, fg: Color.white, dim: true)
        end
      end

      private def render_vertical(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32, val : Float64) : Nil
        total_eighths = (val * height * 8.0).round.to_i

        (0...height).each do |row|
          # Vertical row 0 is top, height - 1 is bottom
          inverted_row = (height - 1) - row
          cell_eighths = (total_eighths - (inverted_row * 8)).clamp(0, 8)
          glyph = Glyphs::VerticalBlocks[cell_eighths]

          pos_ratio = inverted_row.to_f / height.to_f
          fg_color = resolve_color(pos_ratio, val)

          buffer.put_char(x, y + row, glyph, fg: fg_color, bg: Color.hex("#1e293b"))
        end
      end

      private def resolve_color(position_ratio : Float64, val : Float64) : Color
        case @gradient
        when MeterGradient::Heat
          if position_ratio < 0.5
            Color.hex("#38ef7d") # Green
          elsif position_ratio < 0.8
            Color.hex("#ffd200") # Yellow
          else
            Color.hex("#ff0844") # Red
          end
        when MeterGradient::Cool
          if position_ratio < 0.4
            Color.hex("#00c6ff") # Cyan
          elsif position_ratio < 0.75
            Color.hex("#0072ff") # Blue
          else
            Color.hex("#38ef7d") # Mint
          end
        when MeterGradient::Neon
          if position_ratio < 0.5
            Color.hex("#f093fb") # Magenta
          else
            Color.hex("#00f2fe") # Cyan
          end
        else
          @solid_color
        end
      end
    end
  end
end
