require "../control"
require "../../style/color"
require "../../style/visual_width"
require "../../style/theme"

module Opal
  module UI
    # Interactive numeric slider control supporting mouse dragging, wheel scrolling,
    # arrow navigation, custom glyphs, and theming.
    class Slider < Control
      getter value : Float64
      property min : Float64
      property max : Float64
      property step : Float64
      property label : String?
      property? show_value : Bool
      property? disabled : Bool
      property on_change : Proc(Float64, Nil)?

      # Customizable theme and styling
      property track_char : Char = '─'
      property fill_char : Char = '━'
      property thumb_char : Char = '█'
      property track_fg : Color? = nil
      property fill_fg : Color? = nil
      property thumb_fg : Color? = nil
      property label_fg : Color? = nil
      property value_fg : Color? = nil

      # Cached layout coordinates for mouse dragging
      @last_x : Int32 = 0
      @last_y : Int32 = 0
      @last_w : Int32 = 0
      @last_h : Int32 = 1
      @track_start_x : Int32 = 0
      @track_w : Int32 = 0

      def initialize(
        value : Number = 0.0,
        min : Number = 0.0,
        max : Number = 100.0,
        step : Number = 1.0,
        @label : String? = nil,
        @show_value : Bool = true,
        @disabled : Bool = false,
        @on_change : Proc(Float64, Nil)? = nil,
      )
        super()
        @min = min.to_f
        @max = max.to_f
        @step = step.to_f
        @value = value.to_f.clamp(@min, @max)
      end

      def self.new(
        value : Number = 0.0,
        min : Number = 0.0,
        max : Number = 100.0,
        step : Number = 1.0,
        label : String? = nil,
        show_value : Bool = true,
        disabled : Bool = false,
        &block : Float64 -> Nil
      ) : Slider
        new(value: value, min: min, max: max, step: step, label: label, show_value: show_value, disabled: disabled, on_change: block)
      end

      def on_change(&block : Float64 -> Nil) : self
        @on_change = block
        self
      end

      def value=(val : Number)
        clamped = val.to_f.clamp(@min, @max)
        return if @value == clamped
        @value = clamped
        @on_change.try(&.call(@value))
      end

      def handle_key(event : Terminal::KeyEvent) : Bool
        return false if @disabled

        case event.name
        when "left", "down", "h", "j"
          self.value = @value - @step
          true
        when "right", "up", "l", "k"
          self.value = @value + @step
          true
        when "page_down", "pagedown"
          self.value = @value - (@step * 5)
          true
        when "page_up", "pageup"
          self.value = @value + (@step * 5)
          true
        when "home"
          self.value = @min
          true
        when "end"
          self.value = @max
          true
        else
          false
        end
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        return false if @disabled

        case event.button
        when Terminal::MouseButton::WheelUp
          self.value = @value + @step
          return true
        when Terminal::MouseButton::WheelDown
          self.value = @value - @step
          return true
        end

        if event.button == Terminal::MouseButton::Left || event.action == Terminal::MouseAction::Motion
          if @track_w > 0 && event.y == @last_y && event.x >= @track_start_x && event.x <= @track_start_x + @track_w
            ratio = (event.x - @track_start_x).to_f / @track_w.to_f
            target = @min + ratio.clamp(0.0, 1.0) * (@max - @min)
            # Snap to step
            if @step > 0.0
              steps = ((target - @min) / @step).round
              target = @min + steps * @step
            end
            self.value = target
            return true
          end
        end

        false
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        lbl_w = @label ? (VisualWidth.width(@label.not_nil!) + 1) : 0
        val_w = @show_value ? 6 : 0
        min_track_w = 10
        total_w = Math.min(available_w, lbl_w + min_track_w + val_w)
        {Math.max(min_track_w, total_w), 1}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0

        @last_x = x
        @last_y = y
        @last_w = width
        @last_h = 1

        th = current_theme
        t_fg = @track_fg || th.surface
        f_fg = @fill_fg || th.primary
        th_fg = @thumb_fg || th.accent
        l_fg = @label_fg || th.text
        v_fg = @value_fg || th.text_muted

        cur_x = x
        avail_w = width

        # Optional label on left
        if lbl = @label
          lbl_w = VisualWidth.width(lbl)
          if avail_w > lbl_w + 5
            buffer.put_string(cur_x, y, lbl, fg: l_fg)
            cur_x += lbl_w + 1
            avail_w -= lbl_w + 1
          end
        end

        # Optional value text on right
        val_str = ""
        val_w = 0
        if @show_value
          val_str = @value == @value.to_i ? " #{@value.to_i}" : " #{sprintf("%.1f", @value)}"
          val_w = VisualWidth.width(val_str)
        end

        track_total_w = Math.max(0, avail_w - val_w)
        track_total_w = avail_w if track_total_w == 0 && avail_w > 0
        @track_start_x = cur_x
        @track_w = track_total_w

        range = @max - @min
        ratio = range > 0 ? ((@value - @min) / range).clamp(0.0, 1.0) : 0.0
        thumb_pos = track_total_w > 0 ? (ratio * (track_total_w - 1)).round.to_i : 0

        buffer.with_clip(x, y, width, height) do
          # Draw track
          (0...track_total_w).each do |i|
            break if cur_x + i >= x + width
            draw_x = cur_x + i
            if i < thumb_pos
              buffer.put_char(draw_x, y, @fill_char, fg: f_fg)
            elsif i == thumb_pos
              buffer.put_char(draw_x, y, @thumb_char, fg: th_fg, bold: true)
            else
              buffer.put_char(draw_x, y, @track_char, fg: t_fg)
            end
          end

          # Draw value string
          if @show_value && val_w > 0 && cur_x + track_total_w < x + width
            avail_val_w = Math.max(0, (x + width) - (cur_x + track_total_w))
            buffer.put_string(cur_x + track_total_w, y, val_str, fg: v_fg, max_width: avail_val_w)
          end
        end
      end
    end
  end
end
