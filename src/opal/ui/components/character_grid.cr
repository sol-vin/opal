require "../element"
require "../buffer"
require "../control"
require "../../style/color"
require "../../style/border"
require "../../graphics/grid_style"
require "../../graphics/primitives_2d"
require "../../style/visual_width"
require "../../terminal/driver"

module Opal
  module UI
    # Interactive, highly configurable 2D character grid control.
    # Renders regular horizontal and vertical grid lines with customizable intervals,
    # glyph styles (solid, heavy, double, dashed, dotted, crosses, etc.), major/minor lines,
    # panning offsets, interval scaling (zoom), mouse dragging, and coordinate rulers.
    class CharacterGrid < Control
      property interval_x : Int32
      property interval_y : Int32
      property offset_x : Int32
      property offset_y : Int32

      property initial_interval_x : Int32
      property initial_interval_y : Int32

      property major_interval_x : Int32?
      property major_interval_y : Int32?

      property glyphs : Graphics::GridGlyphs
      property current_style : Graphics::GridStylePreset

      property fg : Color
      property bg : Color
      property intersection_fg : Color?
      property major_fg : Color?

      property? show_horizontal : Bool = true
      property? show_vertical : Bool = true
      property? show_coordinates : Bool = false
      property? show_border : Bool = true
      property border_color : Color = Color.hex("#6272A4")
      property border_style : Symbol = :rounded
      property title : String? = "Character Grid"

      property width : Int32
      property height : Int32
      property last_x : Int32 = 0
      property last_y : Int32 = 0
      property last_w : Int32 = 30
      property last_h : Int32 = 12

      # Interactive dragging state
      @dragging : Bool = false
      @drag_start_x : Int32 = 0
      @drag_start_y : Int32 = 0
      @drag_init_ox : Int32 = 0
      @drag_init_oy : Int32 = 0

      # Callbacks
      property on_pan : Proc(Int32, Int32, Nil)? = nil
      property on_interval_change : Proc(Int32, Int32, Nil)? = nil
      property on_style_change : Proc(Graphics::GridStylePreset, Nil)? = nil

      @color_theme_idx : Int32 = 0

      def initialize(
        @interval_x : Int32 = 8,
        @interval_y : Int32 = 4,
        @offset_x : Int32 = 0,
        @offset_y : Int32 = 0,
        style : Symbol | Graphics::GridStylePreset | Graphics::GridGlyphs = :solid,
        @fg : Color = Color.hex("#6272A4"),
        @bg : Color = Color.none,
        @intersection_fg : Color? = Color.hex("#8BE9FD"),
        @major_interval_x : Int32? = nil,
        @major_interval_y : Int32? = nil,
        @major_fg : Color? = Color.hex("#BD93F9"),
        @show_horizontal : Bool = true,
        @show_vertical : Bool = true,
        @show_coordinates : Bool = false,
        @show_border : Bool = true,
        @border_color : Color = Color.hex("#6272A4"),
        @border_style : Symbol = :rounded,
        @title : String? = "Character Grid",
        width : Int32? = 30,
        height : Int32? = 12,
      )
        @initial_interval_x = @interval_x
        @initial_interval_y = @interval_y
        @width = width || 30
        @height = height || 12

        case style
        when Graphics::GridGlyphs
          @glyphs = style
          @current_style = Graphics::GridStylePreset::Solid
        when Graphics::GridStylePreset
          @current_style = style
          @glyphs = Graphics::GridGlyphs.preset(style)
        when Symbol
          preset = Graphics::GridStylePreset.parse?(style) || Graphics::GridStylePreset::Solid
          @current_style = preset
          @glyphs = Graphics::GridGlyphs.preset(preset)
        else
          @current_style = Graphics::GridStylePreset::Solid
          @glyphs = Graphics::GridGlyphs.solid
        end
      end

      # Changes the active grid style preset
      def set_style(preset : Graphics::GridStylePreset | Symbol | String) : Nil
        p = preset.is_a?(Graphics::GridStylePreset) ? preset : (Graphics::GridStylePreset.parse?(preset) || Graphics::GridStylePreset::Solid)
        @current_style = p
        @glyphs = Graphics::GridGlyphs.preset(p)
        @on_style_change.try &.call(p)
      end

      # Cycles through all 10 available presets
      def cycle_style : Graphics::GridStylePreset
        presets = Graphics::GridStylePreset.values
        idx = presets.index(@current_style) || 0
        next_preset = presets[(idx + 1) % presets.size]
        set_style(next_preset)
        next_preset
      end

      # Pans the grid view by (dx, dy)
      def pan(dx : Int32, dy : Int32) : Nil
        @offset_x += dx
        @offset_y += dy
        @on_pan.try &.call(@offset_x, @offset_y)
      end

      # Adjusts grid intervals (zoom)
      def adjust_interval(d_x : Int32, d_y : Int32) : Nil
        @interval_x = Math.max(2, @interval_x + d_x)
        @interval_y = Math.max(1, @interval_y + d_y)
        @on_interval_change.try &.call(@interval_x, @interval_y)
      end

      # Resets pan offsets and intervals to initial creation values
      def reset : Nil
        @offset_x = 0
        @offset_y = 0
        @interval_x = @initial_interval_x
        @interval_y = @initial_interval_y
        @on_pan.try &.call(0, 0)
        @on_interval_change.try &.call(@interval_x, @interval_y)
      end

      # Cycles between built-in color palettes
      def cycle_colors : Nil
        @color_theme_idx = (@color_theme_idx + 1) % 6
        case @color_theme_idx
        when 0 # Dracula / Slate & Cyan
          @fg = Color.hex("#6272A4")
          @intersection_fg = Color.hex("#8BE9FD")
          @major_fg = Color.hex("#BD93F9")
          @bg = Color.none
        when 1 # Phosphor Matrix Green
          @fg = Color.hex("#2E7D32")
          @intersection_fg = Color.hex("#00E676")
          @major_fg = Color.hex("#69F0AE")
          @bg = Color.none
        when 2 # Retro Amber
          @fg = Color.hex("#C67D00")
          @intersection_fg = Color.hex("#FFD54F")
          @major_fg = Color.hex("#FFE082")
          @bg = Color.none
        when 3 # Cyberpunk Magenta / Red
          @fg = Color.hex("#7B1FA2")
          @intersection_fg = Color.hex("#FF79C6")
          @major_fg = Color.hex("#FF5555")
          @bg = Color.none
        when 4 # Blueprint Navy
          @fg = Color.hex("#304FFE")
          @intersection_fg = Color.hex("#82B1FF")
          @major_fg = Color.hex("#E0F7FA")
          @bg = Color.hex("#0B132B")
        when 5 # Monochrome Clean
          @fg = Color.hex("#555555")
          @intersection_fg = Color.hex("#FFFFFF")
          @major_fg = Color.hex("#CCCCCC")
          @bg = Color.none
        end
      end

      def handle_key(key : Terminal::KeyEvent) : Bool
        step = key.shift? ? 5 : 1
        case key.name
        when "left", "h"
          pan(-step, 0)
          true
        when "right", "l"
          pan(step, 0)
          true
        when "up", "k"
          pan(0, -step)
          true
        when "down", "j"
          pan(0, step)
          true
        when "+", "="
          adjust_interval(-1, -1)
          true
        when "-", "_"
          adjust_interval(1, 1)
          true
        when "s", "S"
          cycle_style
          true
        when "c", "C"
          cycle_colors
          true
        when "0"
          reset
          true
        else
          false
        end
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        pad_x = @last_x + (@show_border ? 1 : 0)
        pad_y = @last_y + (@show_border ? 1 : 0)
        pad_w = @show_border ? (@last_w - 2) : @last_w
        pad_h = @show_border ? (@last_h - 2) : @last_h
        return false if pad_w <= 0 || pad_h <= 0

        # Handle mouse wheel zooming or panning
        if event.button.wheel_up?
          adjust_interval(-1, -1)
          return true
        elsif event.button.wheel_down?
          adjust_interval(1, 1)
          return true
        end

        in_area = event.x >= pad_x && event.x < pad_x + pad_w &&
                  event.y >= pad_y && event.y < pad_y + pad_h

        if event.action.press? && in_area
          @dragging = true
          @drag_start_x = event.x
          @drag_start_y = event.y
          @drag_init_ox = @offset_x
          @drag_init_oy = @offset_y
          return true
        elsif event.action.motion? && @dragging
          dx = event.x - @drag_start_x
          dy = event.y - @drag_start_y
          @offset_x = @drag_init_ox + dx
          @offset_y = @drag_init_oy + dy
          @on_pan.try &.call(@offset_x, @offset_y)
          return true
        elsif event.action.release? && @dragging
          @dragging = false
          return true
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
        return if width <= 0 || height <= 0

        # Outer border & titles
        if @show_border
          Graphics::Primitives2D.draw_rect(
            buffer, x, y, width, height,
            border: @border_style,
            fg: @border_color
          )

          # Title on border
          if t = @title
            header_text = " #{t} [#{@current_style.to_s.upcase}] "
            if VisualWidth.measure(header_text) < width - 4
              buffer.put_string(x + 2, y, header_text, fg: Color.white, bold: true)
            end
          end

          # Bottom status readout
          info_str = " #{interval_x}x#{interval_y} | (x:#{offset_x >= 0 ? "+" : ""}#{offset_x}, y:#{offset_y >= 0 ? "+" : ""}#{offset_y}) "
          info_w = VisualWidth.measure(info_str)
          if width > info_w + 6
            buffer.put_string(x + width - info_w - 2, y + height - 1, info_str, fg: @border_color)
          end

          inner_x = x + 1
          inner_y = y + 1
          inner_w = width - 2
          inner_h = height - 2
        else
          inner_x = x
          inner_y = y
          inner_w = width
          inner_h = height
        end

        return if inner_w <= 0 || inner_h <= 0

        # Rulers / Coordinate margins if requested
        if @show_coordinates && inner_w > 4 && inner_h > 2
          # Top ruler
          0.upto(inner_w - 1) do |cx|
            wx = cx - @offset_x
            if (wx % @interval_x) == 0
              coord_label = (wx / @interval_x).to_s
              if coord_label.size == 1
                buffer.put_char(inner_x + cx, inner_y, coord_label[0], fg: @intersection_fg || @fg, dim: true)
              end
            end
          end

          # Left ruler
          0.upto(inner_h - 1) do |cy|
            wy = cy - @offset_y
            if (wy % @interval_y) == 0
              coord_label = (wy / @interval_y).to_s
              if coord_label.size == 1
                buffer.put_char(inner_x, inner_y + cy, coord_label[0], fg: @intersection_fg || @fg, dim: true)
              end
            end
          end

          # Offset grid content by 1 for rulers
          grid_x = inner_x + 1
          grid_y = inner_y + 1
          grid_w = inner_w - 1
          grid_h = inner_h - 1
        else
          grid_x = inner_x
          grid_y = inner_y
          grid_w = inner_w
          grid_h = inner_h
        end

        # Draw grid rasterization
        Graphics::Primitives2D.draw_grid(
          buffer,
          x: grid_x,
          y: grid_y,
          width: grid_w,
          height: grid_h,
          interval_x: @interval_x,
          interval_y: @interval_y,
          offset_x: @offset_x,
          offset_y: @offset_y,
          style: @glyphs,
          fg: @fg,
          bg: @bg,
          intersection_fg: @intersection_fg,
          major_interval_x: @major_interval_x,
          major_interval_y: @major_interval_y,
          major_fg: @major_fg,
          show_horizontal: @show_horizontal,
          show_vertical: @show_vertical
        )
      end
    end
  end
end
