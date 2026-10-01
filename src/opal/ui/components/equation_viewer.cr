require "../element"
require "../buffer"
require "../../style/color"
require "../../style/border"
require "../../graphics/primitives_2d"
require "../../style/visual_width"
require "../../terminal/driver"

module Opal
  module UI
    # Mathematical equation viewer and interactive 2D function grapher.
    # Features 2D Unicode mathematical typesetting (fractions, integrals, radicals, summations)
    # and interactive Cartesian graphing f(x) with braille sub-pixel rendering, zoom, and pan.
    class EquationViewer < Control
      # Unicode character map for superscripts and subscripts
      SUPERSCRIPTS = {
        '0' => '⁰', '1' => '¹', '2' => '²', '3' => '³', '4' => '⁴',
        '5' => '⁵', '6' => '⁶', '7' => '⁷', '8' => '⁸', '9' => '⁹',
        '+' => '⁺', '-' => '⁻', '=' => '⁼', '(' => '⁽', ')' => '⁾',
        'n' => 'ⁿ', 'i' => 'ⁱ', 'x' => 'ˣ', 'y' => 'ʸ',
      }

      SUBSCRIPTS = {
        '0' => '₀', '1' => '₁', '2' => '₂', '3' => '₃', '4' => '₄',
        '5' => '₅', '6' => '₆', '7' => '₇', '8' => '₈', '9' => '₉',
        '+' => '₊', '-' => '₋', '=' => '₌', '(' => '₍', ')' => '₎',
        'a' => 'ₐ', 'e' => 'ₑ', 'i' => 'ᵢ', 'j' => 'ⱼ', 'k' => 'ₖ',
        'n' => 'ₙ', 'x' => 'ₓ',
      }

      # Mathematical typesetting node
      abstract class MathNode
        abstract def render(lines : Array(String), top_offset : Int32) : {Int32, Int32} # returns {width, height}
        abstract def height : Int32
        abstract def width : Int32
      end

      # Plain text or symbol
      class TextNode < MathNode
        getter text : String

        def initialize(@text : String)
        end

        def width : Int32
          VisualWidth.measure(@text)
        end

        def height : Int32
          1
        end

        def render(lines : Array(String), top_offset : Int32) : {Int32, Int32}
          {width, 1}
        end
      end

      # 2D Fraction: numerator over denominator with horizontal bar
      class FractionNode < MathNode
        getter num : String
        getter den : String

        def initialize(@num : String, @den : String)
        end

        def width : Int32
          Math.max(VisualWidth.measure(@num), VisualWidth.measure(@den)) + 2
        end

        def height : Int32
          3
        end

        def render(lines : Array(String), top_offset : Int32) : {Int32, Int32}
          {width, 3}
        end
      end

      # 2D Integral: ∫ with lower and upper bounds and integrand
      class IntegralNode < MathNode
        getter lower : String
        getter upper : String
        getter integrand : String

        def initialize(@lower : String, @upper : String, @integrand : String)
        end

        def width : Int32
          Math.max(VisualWidth.measure(@upper), VisualWidth.measure(@lower)) + VisualWidth.measure(@integrand) + 3
        end

        def height : Int32
          3
        end

        def render(lines : Array(String), top_offset : Int32) : {Int32, Int32}
          {width, 3}
        end
      end

      # Function to graph: receives float x and returns float y = f(x)
      property function : Proc(Float64, Float64)? = nil
      property function_title : String = "f(x)"

      # Viewport bounds
      property x_min : Float64 = -5.0
      property x_max : Float64 = 5.0
      property y_min : Float64 = -3.0
      property y_max : Float64 = 3.0

      # Display settings
      property? show_graph : Bool = true
      property? show_formula : Bool = true
      property math_nodes : Array(MathNode) = Array(MathNode).new

      # Colors
      property curve_color : Color = Color.hex("#8BE9FD")
      property axis_color : Color = Color.hex("#6272A4")
      property grid_color : Color = Color.hex("#44475A")
      property formula_color : Color = Color.hex("#F1FA8C")
      property border_color : Color = Color.hex("#FF79C6")

      property width : Int32
      property height : Int32
      property last_x : Int32 = 0
      property last_y : Int32 = 0
      property last_w : Int32 = 42
      property last_h : Int32 = 16

      def initialize(
        @function_title : String = "f(x) = sin(x)",
        @x_min : Float64 = -5.0,
        @x_max : Float64 = 5.0,
        @y_min : Float64 = -3.0,
        @y_max : Float64 = 3.0,
        @width : Int32 = 42,
        @height : Int32 = 16,
        @function : Proc(Float64, Float64)? = nil,
      )
        @last_w = @width
        @last_h = @height
        super()
      end

      def self.new(
        function_title : String = "f(x) = sin(x)",
        x_min : Float64 = -5.0,
        x_max : Float64 = 5.0,
        y_min : Float64 = -3.0,
        y_max : Float64 = 3.0,
        width : Int32 = 42,
        height : Int32 = 16,
        &block : Float64 -> Float64
      )
        new(
          function_title: function_title,
          x_min: x_min,
          x_max: x_max,
          y_min: y_min,
          y_max: y_max,
          width: width,
          height: height,
          function: block
        )
      end

      # Converts a regular string with ^(exp) or _(sub) into Unicode super/subscripts
      def self.format_super_sub(expr : String) : String
        String.build do |io|
          i = 0
          chars = expr.chars
          while i < chars.size
            if chars[i] == '^' && i + 1 < chars.size
              if chars[i + 1] == '('
                # parse until ')'
                j = i + 2
                while j < chars.size && chars[j] != ')'
                  ch = chars[j]
                  io << (SUPERSCRIPTS[ch]? || ch)
                  j += 1
                end
                i = j < chars.size ? j + 1 : j
              else
                ch = chars[i + 1]
                io << (SUPERSCRIPTS[ch]? || ch)
                i += 2
              end
            elsif chars[i] == '_' && i + 1 < chars.size
              if chars[i + 1] == '('
                j = i + 2
                while j < chars.size && chars[j] != ')'
                  ch = chars[j]
                  io << (SUBSCRIPTS[ch]? || ch)
                  j += 1
                end
                i = j < chars.size ? j + 1 : j
              else
                ch = chars[i + 1]
                io << (SUBSCRIPTS[ch]? || ch)
                i += 2
              end
            else
              io << chars[i]
              i += 1
            end
          end
        end
      end

      # Formats a square root: √(expr) with Unicode overbar
      def self.sqrt_text(inner : String) : String
        "√(" + inner + ")"
      end

      # Adds a fraction node
      def add_fraction(num : String, den : String) : Nil
        @math_nodes << FractionNode.new(num, den)
      end

      # Adds an integral node
      def add_integral(lower : String, upper : String, integrand : String) : Nil
        @math_nodes << IntegralNode.new(lower, upper, integrand)
      end

      # Adds a text node
      def add_text(text : String) : Nil
        @math_nodes << TextNode.new(text)
      end

      # Zooms in/out
      def zoom(factor : Float64) : Nil
        center_x = (@x_min + @x_max) / 2.0
        center_y = (@y_min + @y_max) / 2.0
        span_x = (@x_max - @x_min) * factor
        span_y = (@y_max - @y_min) * factor

        @x_min = center_x - span_x / 2.0
        @x_max = center_x + span_x / 2.0
        @y_min = center_y - span_y / 2.0
        @y_max = center_y + span_y / 2.0
      end

      # Pans viewport
      def pan(dx_pct : Float64, dy_pct : Float64) : Nil
        span_x = @x_max - @x_min
        span_y = @y_max - @y_min
        @x_min += span_x * dx_pct
        @x_max += span_x * dx_pct
        @y_min += span_y * dy_pct
        @y_max += span_y * dy_pct
      end

      def handle_key(key : Terminal::KeyEvent) : Bool
        case key.name
        when "+", "="
          zoom(0.8) # Zoom in
          true
        when "-", "_"
          zoom(1.25) # Zoom out
          true
        when "0"
          # Reset view
          @x_min = -5.0
          @x_max = 5.0
          @y_min = -3.0
          @y_max = 3.0
          true
        when "left", "h"
          pan(-0.1, 0.0)
          true
        when "right", "l"
          pan(0.1, 0.0)
          true
        when "up", "k"
          pan(0.0, 0.1)
          true
        when "down", "j"
          pan(0.0, -0.1)
          true
        else
          false
        end
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        # Scroll wheel zooms
        if event.button.wheel_up?
          zoom(0.85)
          true
        elsif event.button.wheel_down?
          zoom(1.15)
          true
        else
          false
        end
      end

      private def braille_bit(dot_x : Int32, dot_y : Int32) : Int32
        case {dot_x, dot_y}
        when {0, 0} then 0x01
        when {0, 1} then 0x02
        when {0, 2} then 0x04
        when {1, 0} then 0x08
        when {1, 1} then 0x10
        when {1, 2} then 0x20
        when {0, 3} then 0x40
        when {1, 3} then 0x80
        else             0x00
        end
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
        return if w <= 4 || h <= 4

        bx = x
        by = y

        # Border
        Graphics::Primitives2D.draw_rect(buffer, bx, by, w, h, border: :rounded, fg: @border_color)

        inner_x = bx + 1
        inner_y = by + 1
        inner_w = w - 2
        inner_h = h - 2
        return if inner_w <= 0 || inner_h <= 0

        # Title bar with mathematical formula
        title_str = " #{@function_title} [+/- Zoom, Arrows Pan] "
        buffer.put_string(inner_x + 1, by, title_str, fg: @formula_color)

        # Formula / 2D Math Nodes display area (top rows if math nodes present)
        formula_height = 0
        if @show_formula && !@math_nodes.empty?
          cur_x = inner_x + 1
          @math_nodes.each do |node|
            case node
            when FractionNode
              fn_w = node.width
              # Numerator centered
              num_pad = (fn_w - VisualWidth.measure(node.num)) // 2
              buffer.put_string(cur_x + num_pad, inner_y, node.num, fg: @formula_color)
              # Horizontal division bar
              fn_w.times do |i|
                buffer.put_char(cur_x + i, inner_y + 1, '─', fg: @formula_color)
              end
              # Denominator centered
              den_pad = (fn_w - VisualWidth.measure(node.den)) // 2
              buffer.put_string(cur_x + den_pad, inner_y + 2, node.den, fg: @formula_color)
              cur_x += fn_w + 1
              formula_height = Math.max(formula_height, 3)
            when IntegralNode
              int_w = node.width
              buffer.put_string(cur_x + 2, inner_y, node.upper, fg: @formula_color)
              buffer.put_char(cur_x, inner_y, '⌠', fg: @formula_color)
              buffer.put_char(cur_x, inner_y + 1, '│', fg: @formula_color)
              buffer.put_char(cur_x, inner_y + 2, '⌡', fg: @formula_color)
              buffer.put_string(cur_x + 2, inner_y + 2, node.lower, fg: @formula_color)
              buffer.put_string(cur_x + 4, inner_y + 1, node.integrand, fg: @formula_color)
              cur_x += int_w + 1
              formula_height = Math.max(formula_height, 3)
            when TextNode
              buffer.put_string(cur_x, inner_y + 1, node.text, fg: @formula_color)
              cur_x += node.width + 1
              formula_height = Math.max(formula_height, 1)
            end
          end
          # Add separator line
          formula_height += 1
        end

        # Graph area
        graph_y = inner_y + formula_height
        graph_h = inner_h - formula_height
        return if graph_h <= 2 || !@show_graph

        # Clear graph area
        (0...graph_h).each do |cy|
          (0...inner_w).each do |cx|
            buffer.put_char(inner_x + cx, graph_y + cy, ' ')
          end
        end

        # Draw Cartesian axes if in view
        # x-axis is at y = 0
        span_x = @x_max - @x_min
        span_y = @y_max - @y_min

        # Origin screen position
        axis_x_cell = span_x > 0 ? ((-@x_min / span_x) * (inner_w - 1)).round.to_i : -1
        axis_y_cell = span_y > 0 ? ((1.0 - (-@y_min / span_y)) * (graph_h - 1)).round.to_i : -1

        # Draw X-axis
        if axis_y_cell >= 0 && axis_y_cell < graph_h
          (0...inner_w).each do |cx|
            buffer.put_char(inner_x + cx, graph_y + axis_y_cell, '─', fg: @axis_color)
          end
        end

        # Draw Y-axis
        if axis_x_cell >= 0 && axis_x_cell < inner_w
          (0...graph_h).each do |cy|
            buffer.put_char(inner_x + axis_x_cell, graph_y + cy, '│', fg: @axis_color)
          end
        end

        # Origin cross
        if axis_x_cell >= 0 && axis_x_cell < inner_w && axis_y_cell >= 0 && axis_y_cell < graph_h
          buffer.put_char(inner_x + axis_x_cell, graph_y + axis_y_cell, '┼', fg: @axis_color)
        end

        # Graph the function using Braille sub-pixel resolution
        if fn = @function
          sub_w = inner_w * 2
          sub_h = graph_h * 4

          braille_cells = Array(Int32).new(inner_w * graph_h, 0)

          sub_w.times do |dot_x|
            # Map dot_x to math domain x
            math_x = @x_min + (dot_x.to_f / (sub_w - 1).to_f) * span_x
            math_y = fn.call(math_x)

            if !math_y.nan? && !math_y.infinite? && math_y >= @y_min && math_y <= @y_max
              # Map math_y to sub_pixel dot_y (Cartesian: top is y_max)
              dot_y = ((@y_max - math_y) / span_y * (sub_h - 1)).round.to_i.clamp(0, sub_h - 1)

              cell_x = dot_x // 2
              cell_y = dot_y // 4

              if cell_x >= 0 && cell_x < inner_w && cell_y >= 0 && cell_y < graph_h
                bit = braille_bit(dot_x % 2, dot_y % 4)
                idx = cell_y * inner_w + cell_x
                braille_cells[idx] |= bit
              end
            end
          end

          # Render Braille cells
          (0...graph_h).each do |cy|
            (0...inner_w).each do |cx|
              bits = braille_cells[cy * inner_w + cx]
              if bits > 0
                braille_char = (0x2800 + bits).chr
                buffer.put_char(inner_x + cx, graph_y + cy, braille_char, fg: @curve_color)
              end
            end
          end
        end

        # Coordinate domain readouts at corners
        x_min_str = sprintf("%.1f", @x_min)
        x_max_str = sprintf("%.1f", @x_max)
        buffer.put_string(inner_x, graph_y + graph_h - 1, x_min_str, fg: Color.hex("#6272A4"))
        buffer.put_string(inner_x + inner_w - VisualWidth.measure(x_max_str), graph_y + graph_h - 1, x_max_str, fg: Color.hex("#6272A4"))
      end
    end
  end
end
