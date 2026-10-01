require "../element"
require "../buffer"
require "../../style/color"
require "../../style/border"
require "../../graphics/primitives_2d"
require "../../style/visual_width"
require "../../terminal/driver"

module Opal
  module UI
    # Interactive 2D continuous target/coordinate selector.
    # Supports custom X/Y continuous domains, procedural background shader blocks,
    # static buffer backgrounds, custom reticle glyphs, mouse dragging, and arrow-key stepping.
    class TargetSelector2D < Control
      property x_min : Float64
      property x_max : Float64
      property y_min : Float64
      property y_max : Float64

      property x_val : Float64
      property y_val : Float64
      property step_x : Float64
      property step_y : Float64

      property reticle_char : Char = '⌖'
      property reticle_color : Color = Color.white
      property show_coordinates : Bool = true
      property? border : Bool = true
      property border_color : Color = Color.hex("#6272A4")
      property background_color : Color = Color.hex("#1E1E2E")

      # Optional procedural background generator: receives normalized (u, v) in [0.0..1.0] and returns a Color
      property background_shader : Proc(Float64, Float64, Color)? = nil

      # Optional pre-rendered background buffer
      property background_buffer : Buffer? = nil

      # Callbacks
      property on_change : Proc(Float64, Float64, Nil)? = nil
      property on_confirm : Proc(Float64, Float64, Nil)? = nil
      getter? confirmed : Bool = false

      property width : Int32
      property height : Int32
      property last_x : Int32 = 0
      property last_y : Int32 = 0
      property last_w : Int32 = 24
      property last_h : Int32 = 10

      def initialize(
        x_range : Range(Float64, Float64) = 0.0..1.0,
        y_range : Range(Float64, Float64) = 0.0..1.0,
        initial_x : Float64? = nil,
        initial_y : Float64? = nil,
        @reticle_char : Char = '⌖',
        @show_coordinates : Bool = true,
        @border : Bool = true,
        width : Int32? = 24,
        height : Int32? = 10,
        @background_shader : Proc(Float64, Float64, Color)? = nil,
      )
        @x_min = x_range.begin
        @x_max = x_range.end
        @y_min = y_range.begin
        @y_max = y_range.end

        @x_val = (initial_x || ((@x_min + @x_max) / 2.0)).clamp(@x_min, @x_max)
        @y_val = (initial_y || ((@y_min + @y_max) / 2.0)).clamp(@y_min, @y_max)

        @step_x = (@x_max - @x_min).abs / 50.0
        @step_y = (@y_max - @y_min).abs / 50.0
        @step_x = 0.02 if @step_x <= 0.0
        @step_y = 0.02 if @step_y <= 0.0

        @width = width || 24
        @height = height || 10
        @last_w = @width
        @last_h = @height
        super()
      end

      def self.new(
        x_range : Range(Float64, Float64) = 0.0..1.0,
        y_range : Range(Float64, Float64) = 0.0..1.0,
        initial_x : Float64? = nil,
        initial_y : Float64? = nil,
        reticle_char : Char = '⌖',
        show_coordinates : Bool = true,
        border : Bool = true,
        width : Int32? = 24,
        height : Int32? = 10,
        &block : Float64, Float64 -> Color
      )
        new(
          x_range: x_range,
          y_range: y_range,
          initial_x: initial_x,
          initial_y: initial_y,
          reticle_char: reticle_char,
          show_coordinates: show_coordinates,
          border: border,
          width: width,
          height: height,
          background_shader: block
        )
      end

      # Sets current coordinate values and triggers on_change if changed
      def set_values(x : Float64, y : Float64) : Nil
        new_x = x.clamp(@x_min, @x_max)
        new_y = y.clamp(@y_min, @y_max)
        if new_x != @x_val || new_y != @y_val
          @x_val = new_x
          @y_val = new_y
          @on_change.try &.call(@x_val, @y_val)
        end
      end

      # Returns normalized (u, v) in [0.0..1.0]
      def normalized_coords : {Float64, Float64}
        u = @x_max == @x_min ? 0.5 : ((@x_val - @x_min) / (@x_max - @x_min)).clamp(0.0, 1.0)
        v = @y_max == @y_min ? 0.5 : ((@y_val - @y_min) / (@y_max - @y_min)).clamp(0.0, 1.0)
        {u, v}
      end

      # Sets coordinates from normalized (u, v) in [0.0..1.0]
      def set_from_normalized(u : Float64, v : Float64) : Nil
        nx = @x_min + u.clamp(0.0, 1.0) * (@x_max - @x_min)
        ny = @y_min + v.clamp(0.0, 1.0) * (@y_max - @y_min)
        set_values(nx, ny)
      end

      def handle_key(key : Terminal::KeyEvent) : Bool
        step_mult = key.shift? ? 0.2 : 1.0
        case key.name
        when "left", "h"
          set_values(@x_val - @step_x * step_mult, @y_val)
          true
        when "right", "l"
          set_values(@x_val + @step_x * step_mult, @y_val)
          true
        when "up", "k"
          set_values(@x_val, @y_val + @step_y * step_mult)
          true
        when "down", "j"
          set_values(@x_val, @y_val - @step_y * step_mult)
          true
        when "enter", "space"
          @confirmed = true
          @on_confirm.try &.call(@x_val, @y_val)
          true
        else
          false
        end
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        pad_x = @last_x + (@border ? 1 : 0)
        pad_y = @last_y + (@border ? 1 : 0)
        pad_w = @border ? (@last_w - 2) : @last_w
        pad_h = @border ? (@last_h - 2) : @last_h
        return false if pad_w <= 0 || pad_h <= 0

        if (event.action.press? || event.action.motion?)
          ex = (event.x >= pad_x && event.x < pad_x + pad_w) ? event.x : event.x - 1
          ey = (event.y >= pad_y && event.y < pad_y + pad_h) ? event.y : event.y - 1
          if ex >= pad_x && ex < pad_x + pad_w &&
             ey >= pad_y && ey < pad_y + pad_h
            u = (ex - pad_x).to_f / Math.max(1, pad_w - 1).to_f
            # Invert Y so bottom is min, top is max (standard Cartesian)
            v = 1.0 - ((ey - pad_y).to_f / Math.max(1, pad_h - 1).to_f)
            set_from_normalized(u, v)
            return true
          end
        end
        false
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        {Math.min(available_w, @width), Math.min(available_h, @height)}
      end

      def render(buffer : Buffer) : Nil
        render(buffer, @last_x, @last_y, @width, @height)
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        @last_x = x
        @last_y = y
        @last_w = width
        @last_h = height
        @width = width
        @height = height
        w = width
        h = height
        return if w <= 2 || h <= 2

        bx = x
        by = y

        # Border
        if @border
          Graphics::Primitives2D.draw_rect(buffer, bx, by, w, h, border: :rounded, fg: @border_color)
          inner_x = bx + 1
          inner_y = by + 1
          inner_w = w - 2
          inner_h = h - 2
        else
          inner_x = bx
          inner_y = by
          inner_w = w
          inner_h = h
        end

        return if inner_w <= 0 || inner_h <= 0

        # Background rendering
        if bg_buf = @background_buffer
          # Copy from static buffer
          (0...inner_h).each do |cy|
            (0...inner_w).each do |cx|
              if cy < bg_buf.height && cx < bg_buf.width
                cell = bg_buf.get(cx, cy)
                buffer.put_char(inner_x + cx, inner_y + cy, cell.char, fg: cell.fg, bg: cell.bg)
              else
                buffer.put_char(inner_x + cx, inner_y + cy, ' ', fg: Color.none, bg: @background_color)
              end
            end
          end
        elsif shader = @background_shader
          # Procedural background shader
          (0...inner_h).each do |cy|
            v = 1.0 - (cy.to_f / Math.max(1, inner_h - 1).to_f)
            (0...inner_w).each do |cx|
              u = cx.to_f / Math.max(1, inner_w - 1).to_f
              cell_col = shader.call(u, v)
              buffer.put_char(inner_x + cx, inner_y + cy, ' ', fg: Color.none, bg: cell_col)
            end
          end
        else
          # Fallback grid / crosshairs pattern
          (0...inner_h).each do |cy|
            mid_y = cy == (inner_h / 2)
            (0...inner_w).each do |cx|
              mid_x = cx == (inner_w / 2)
              ch = if mid_x && mid_y
                     '┼'
                   elsif mid_x
                     '│'
                   elsif mid_y
                     '─'
                   elsif (cx + cy) % 4 == 0
                     '·'
                   else
                     ' '
                   end
              buffer.put_char(inner_x + cx, inner_y + cy, ch, fg: Color.hex("#44475A"), bg: @background_color)
            end
          end
        end

        # Calculate Reticle screen position
        u, v = normalized_coords
        rx = inner_x + (u * (inner_w - 1)).round.to_i.clamp(0, inner_w - 1)
        # Cartesian: v=1 is top, v=0 is bottom
        ry = inner_y + ((1.0 - v) * (inner_h - 1)).round.to_i.clamp(0, inner_h - 1)

        # Crosshair lines around reticle (subtle 3-point cross)
        if rx > inner_x
          buffer.put_char(rx - 1, ry, '─', fg: @reticle_color)
        end
        if rx < inner_x + inner_w - 1
          buffer.put_char(rx + 1, ry, '─', fg: @reticle_color)
        end
        if ry > inner_y
          buffer.put_char(rx, ry - 1, '│', fg: @reticle_color)
        end
        if ry < inner_y + inner_h - 1
          buffer.put_char(rx, ry + 1, '│', fg: @reticle_color)
        end

        # Reticle center
        buffer.put_char(rx, ry, @reticle_char, fg: @reticle_color)

        # Coordinate label overlay
        if @show_coordinates
          coord_str = sprintf("X:%.2f Y:%.2f", @x_val, @y_val)
          label_x = inner_x + inner_w - VisualWidth.measure(coord_str) - 1
          label_y = inner_y + inner_h - 1
          if label_x >= inner_x && label_y >= inner_y
            buffer.put_string(label_x, label_y, coord_str, fg: Color.hex("#F8F8F2"), bg: Color.hex("#282A36"))
          end
        end
      end
    end
  end
end
