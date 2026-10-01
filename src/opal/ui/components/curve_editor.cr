require "../element"
require "../buffer"
require "../../style/color"
require "../../style/border"
require "../../graphics/primitives_2d"
require "../../style/visual_width"
require "../../terminal/driver"

module Opal
  module UI
    # Interactive Bézier Curve & Easing Editor.
    # Features 2x4 sub-pixel Unicode Braille plotting, draggable P1/P2 control handles,
    # CSS cubic-bezier output, standard presets, and real-time physics easing preview.
    class CurveEditor < Control
      property p1_x : Float64
      property p1_y : Float64
      property p2_x : Float64
      property p2_y : Float64

      # Active handle being manipulated: 1 for P1, 2 for P2
      property active_handle : Int32 = 1

      # Visual styling
      property curve_color : Color = Color.hex("#50FA7B")
      property handle_p1_color : Color = Color.hex("#FF79C6")
      property handle_p2_color : Color = Color.hex("#8BE9FD")
      property grid_color : Color = Color.hex("#44475A")
      property border_color : Color = Color.hex("#BD93F9")
      property show_ball_track : Bool = true
      property anim_progress : Float64 = 0.0 # Time t in [0.0..1.0]

      # Callbacks
      property on_change : Proc(Float64, Float64, Float64, Float64, Nil)? = nil

      # Presets
      PRESETS = {
        "linear"        => {0.0, 0.0, 1.0, 1.0},
        "ease"          => {0.25, 0.1, 0.25, 1.0},
        "ease_in"       => {0.42, 0.0, 1.0, 1.0},
        "ease_out"      => {0.0, 0.0, 0.58, 1.0},
        "ease_in_out"   => {0.42, 0.0, 0.58, 1.0},
        "ease_in_back"  => {0.36, 0.0, 0.66, -0.56},
        "ease_out_back" => {0.34, 1.56, 0.64, 1.0},
      }

      property width : Int32
      property height : Int32
      property last_x : Int32 = 0
      property last_y : Int32 = 0
      property last_w : Int32 = 36
      property last_h : Int32 = 16

      def initialize(
        p1_x : Float64 = 0.42,
        p1_y : Float64 = 0.0,
        p2_x : Float64 = 0.58,
        p2_y : Float64 = 1.0,
        @width : Int32 = 36,
        @height : Int32 = 16,
      )
        @p1_x = p1_x.clamp(0.0, 1.0)
        @p1_y = p1_y.clamp(-1.0, 2.0)
        @p2_x = p2_x.clamp(0.0, 1.0)
        @p2_y = p2_y.clamp(-1.0, 2.0)
        @last_w = @width
        @last_h = @height

        super()
      end

      # Applies a named preset (e.g. "ease_in_out", "ease", "linear")
      def preset(name : String) : Nil
        if vals = PRESETS[name]?
          @p1_x, @p1_y, @p2_x, @p2_y = vals
          @on_change.try &.call(@p1_x, @p1_y, @p2_x, @p2_y)
        end
      end

      # Generates CSS cubic-bezier string
      def to_css : String
        sprintf("cubic-bezier(%.2f, %.2f, %.2f, %.2f)", @p1_x, @p1_y, @p2_x, @p2_y)
      end

      # Evaluates cubic Bézier parametric coordinate (bx, by) at parameter t in [0.0..1.0]
      def sample_bezier(t : Float64) : {Float64, Float64}
        u = 1.0 - t
        tt = t * t
        uu = u * u
        uuu = uu * u
        ttt = tt * t

        # P0 = (0, 0), P3 = (1, 1)
        bx = 3.0 * uu * t * @p1_x + 3.0 * u * tt * @p2_x + ttt
        by = 3.0 * uu * t * @p1_y + 3.0 * u * tt * @p2_y + ttt

        {bx, by}
      end

      # Solves for y given x in [0.0..1.0] using bisection (approximate inversion for animation easing)
      def evaluate_easing(x : Float64) : Float64
        return 0.0 if x <= 0.0
        return 1.0 if x >= 1.0

        low = 0.0
        high = 1.0
        t = x

        8.times do
          bx, _ = sample_bezier(t)
          if (bx - x).abs < 1e-4
            break
          elsif bx < x
            low = t
          else
            high = t
          end
          t = (low + high) / 2.0
        end

        _, by = sample_bezier(t)
        by
      end

      # Increments animation preview progress
      def tick_anim(delta : Float64 = 0.05) : Nil
        @anim_progress = (@anim_progress + delta) % 1.0
      end

      def handle_key(key : Terminal::KeyEvent) : Bool
        step = key.shift? ? 0.01 : 0.05
        case key.name
        when "tab"
          @active_handle = @active_handle == 1 ? 2 : 1
          true
        when "1"
          @active_handle = 1
          true
        when "2"
          @active_handle = 2
          true
        when "L", "shift+l"
          preset("linear")
          true
        when "E", "shift+e"
          preset("ease")
          true
        when "I", "shift+i"
          preset("ease_in")
          true
        when "O", "shift+o"
          preset("ease_out")
          true
        when "P", "shift+p"
          preset("ease_in_out")
          true
        when "left", "h"
          if @active_handle == 1
            @p1_x = (@p1_x - step).clamp(0.0, 1.0)
          else
            @p2_x = (@p2_x - step).clamp(0.0, 1.0)
          end
          @on_change.try &.call(@p1_x, @p1_y, @p2_x, @p2_y)
          true
        when "right", "l"
          if @active_handle == 1
            @p1_x = (@p1_x + step).clamp(0.0, 1.0)
          else
            @p2_x = (@p2_x + step).clamp(0.0, 1.0)
          end
          @on_change.try &.call(@p1_x, @p1_y, @p2_x, @p2_y)
          true
        when "up", "k"
          if @active_handle == 1
            @p1_y = (@p1_y + step).clamp(-1.0, 2.0)
          else
            @p2_y = (@p2_y + step).clamp(-1.0, 2.0)
          end
          @on_change.try &.call(@p1_x, @p1_y, @p2_x, @p2_y)
          true
        when "down", "j"
          if @active_handle == 1
            @p1_y = (@p1_y - step).clamp(-1.0, 2.0)
          else
            @p2_y = (@p2_y - step).clamp(-1.0, 2.0)
          end
          @on_change.try &.call(@p1_x, @p1_y, @p2_x, @p2_y)
          true
        else
          false
        end
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        bx = @last_x + 1
        by = @last_y + 1
        bw = @last_w - 2
        bh = @show_ball_track ? (@last_h - 4) : (@last_h - 2)
        return false if bw <= 0 || bh <= 0

        if (event.action.press? || event.action.motion?)
          ex = (event.x >= bx && event.x < bx + bw) ? event.x : event.x - 1
          ey = (event.y >= by && event.y < by + bh) ? event.y : event.y - 1
          if ex >= bx && ex < bx + bw && ey >= by && ey < by + bh
            nx = ((ex - bx).to_f / Math.max(1, bw - 1).to_f).clamp(0.0, 1.0)
            ny = (1.0 - ((ey - by).to_f / Math.max(1, bh - 1).to_f)).clamp(-0.5, 1.5)

            # Determine closest handle on initial click if not already dragging
            if event.action.press?
              d1 = (nx - @p1_x).abs + (ny - @p1_y).abs
              d2 = (nx - @p2_x).abs + (ny - @p2_y).abs
              @active_handle = d1 < d2 ? 1 : 2
            end

            if @active_handle == 1
              @p1_x = nx
              @p1_y = ny
            else
              @p2_x = nx
              @p2_y = ny
            end
            @on_change.try &.call(@p1_x, @p1_y, @p2_x, @p2_y)
            return true
          end
        end
        false
      end

      # Braille sub-pixel dot mapping:
      # Unicode Braille patterns are indexed from 0x2800 to 0x28FF.
      # In each character cell: 2 dots wide (col 0..1), 4 dots high (row 0..3).
      # Bits:
      # Row 0: col 0 -> 0x01, col 1 -> 0x08
      # Row 1: col 0 -> 0x02, col 1 -> 0x10
      # Row 2: col 0 -> 0x04, col 1 -> 0x20
      # Row 3: col 0 -> 0x40, col 1 -> 0x80
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

        # Draw frame
        Graphics::Primitives2D.draw_rect(buffer, bx, by, w, h, border: :rounded, fg: @border_color)

        inner_x = bx + 1
        inner_y = by + 1
        inner_w = w - 2
        plot_h = @show_ball_track ? (h - 5) : (h - 3)
        return if inner_w <= 0 || plot_h <= 0

        # Title / Formula bar at top
        css_label = to_css
        active_lbl = " [Active: P#{@active_handle}]"
        buffer.put_string(inner_x, by, " #{css_label}#{active_lbl} ", fg: Color.hex("#F1FA8C"))

        # Clear plot area
        (0...plot_h).each do |cy|
          (0...inner_w).each do |cx|
            # Draw baseline and 1.0 ceiling guidelines
            ch = if cy == plot_h - 1
                   '─'
                 elsif cy == 0
                   '┄'
                 else
                   ' '
                 end
            buffer.put_char(inner_x + cx, inner_y + cy, ch, fg: @grid_color)
          end
        end

        # Sub-pixel Braille Matrix
        sub_w = inner_w * 2
        sub_h = plot_h * 4

        # Array of subpixel braille bitmasks per cell
        braille_cells = Array(Int32).new(inner_w * plot_h, 0)

        # Plot curve using 100 parametric samples
        120.times do |step|
          t = step.to_f / 119.0
          cx, cy = sample_bezier(t)

          dot_x = (cx * (sub_w - 1)).round.to_i.clamp(0, sub_w - 1)
          # Invert Y: cy=0 is bottom, cy=1 is top
          dot_y = ((1.0 - cy) * (sub_h - 1)).round.to_i.clamp(0, sub_h - 1)

          cell_x = dot_x // 2
          cell_y = dot_y // 4

          if cell_x >= 0 && cell_x < inner_w && cell_y >= 0 && cell_y < plot_h
            sub_col = dot_x % 2
            sub_row = dot_y % 4
            bit = braille_bit(sub_col, sub_row)
            idx = cell_y * inner_w + cell_x
            braille_cells[idx] |= bit
          end
        end

        # Write Braille curve to buffer
        (0...plot_h).each do |cy|
          (0...inner_w).each do |cx|
            bits = braille_cells[cy * inner_w + cx]
            if bits > 0
              braille_char = (0x2800 + bits).chr
              buffer.put_char(inner_x + cx, inner_y + cy, braille_char, fg: @curve_color)
            end
          end
        end

        # Draw Control Point Handle Lines & Nodes
        p1_cell_x = inner_x + (@p1_x * (inner_w - 1)).round.to_i.clamp(0, inner_w - 1)
        p1_cell_y = inner_y + ((1.0 - @p1_y) * (plot_h - 1)).round.to_i.clamp(0, plot_h - 1)

        p2_cell_x = inner_x + (@p2_x * (inner_w - 1)).round.to_i.clamp(0, inner_w - 1)
        p2_cell_y = inner_y + ((1.0 - @p2_y) * (plot_h - 1)).round.to_i.clamp(0, plot_h - 1)

        # Draw handles
        p1_glyph = @active_handle == 1 ? '◉' : '○'
        p2_glyph = @active_handle == 2 ? '◉' : '○'

        buffer.put_char(p1_cell_x, p1_cell_y, p1_glyph, fg: @handle_p1_color)
        buffer.put_char(p2_cell_x, p2_cell_y, p2_glyph, fg: @handle_p2_color)

        # Labels for handles
        buffer.put_string(inner_x + 1, inner_y, "P1:(#{@p1_x.round(2)}, #{@p1_y.round(2)})", fg: @handle_p1_color)
        p2_str = "P2:(#{@p2_x.round(2)}, #{@p2_y.round(2)})"
        buffer.put_string(inner_x + inner_w - VisualWidth.measure(p2_str) - 1, inner_y, p2_str, fg: @handle_p2_color)

        # Physics Easing Ball Track
        if @show_ball_track
          track_y = inner_y + plot_h + 1
          buffer.put_string(inner_x, track_y, "Ease Track: [", fg: Color.hex("#6272A4"))

          track_w = inner_w - 15
          if track_w > 4
            track_start_x = inner_x + 13
            # Current eased position
            eased_y = evaluate_easing(@anim_progress).clamp(0.0, 1.0)
            ball_pos = (eased_y * (track_w - 1)).round.to_i.clamp(0, track_w - 1)

            (0...track_w).each do |tx|
              ch = (tx == ball_pos) ? '●' : '┄'
              fg = (tx == ball_pos) ? Color.hex("#FF5555") : Color.hex("#44475A")
              buffer.put_char(track_start_x + tx, track_y, ch, fg: fg)
            end
            buffer.put_string(track_start_x + track_w, track_y, "]", fg: Color.hex("#6272A4"))
          end
        end
      end
    end
  end
end
