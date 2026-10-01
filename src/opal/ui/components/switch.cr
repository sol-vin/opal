require "../control"
require "../../style/color"
require "../../style/visual_width"

module Opal
  module UI
    # Interactive toggle switch widget inspired by Python Textual's Switch.
    # Features smooth pill-track rendering, keyboard (Space/Enter) toggle,
    # mouse click hit-testing, customizable ON/OFF glyphs and colors,
    # and change callbacks.
    class Switch < Control
      property label : String?
      property? on : Bool
      property? disabled : Bool
      property on_change : Proc(Bool, Nil)?

      # Manipulable theme properties and glyph swaps
      property on_thumb_fg : Color? = nil
      property on_thumb_bg : Color? = nil
      property on_track_fg : Color? = nil
      property on_track_bg : Color? = nil

      property off_thumb_fg : Color? = nil
      property off_thumb_bg : Color? = nil
      property off_track_fg : Color? = nil
      property off_track_bg : Color? = nil

      property label_fg : Color? = nil
      property focus_border_fg : Color? = nil

      property thumb_char : Char? = nil
      property track_char : Char? = nil

      # Cached layout coordinates for mouse interaction
      @last_x : Int32 = 0
      @last_y : Int32 = 0
      @last_w : Int32 = 0
      @last_h : Int32 = 1

      def initialize(
        @label : String? = nil,
        @on : Bool = false,
        @disabled : Bool = false,
        @on_change : Proc(Bool, Nil)? = nil,
      )
        super()
      end

      def self.new(
        label : String? = nil,
        on : Bool = false,
        disabled : Bool = false,
        &block : Bool -> Nil
      ) : Switch
        new(label: label, on: on, disabled: disabled, on_change: block)
      end

      def on_change(&block : Bool -> Nil) : self
        @on_change = block
        self
      end

      # Toggles state if not disabled
      def toggle : self
        return self if @disabled
        @on = !@on
        @on_change.try(&.call(@on))
        self
      end

      def on=(val : Bool)
        return if @on == val
        @on = val
        @on_change.try(&.call(@on))
      end

      def handle_key(event : Terminal::KeyEvent) : Bool
        return false if @disabled

        case event.name
        when "space", " ", "enter", "return"
          toggle
          true
        when "left"
          if @on
            toggle
            true
          else
            false
          end
        when "right"
          if !@on
            toggle
            true
          else
            false
          end
        else
          false
        end
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        return false if @disabled

        if event.button == Terminal::MouseButton::Left && event.action == Terminal::MouseAction::Press
          if event.x >= @last_x && event.x < @last_x + @last_w &&
             event.y >= @last_y && event.y < @last_y + @last_h
            toggle
            return true
          end
        end
        false
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        switch_w = 6 # e.g. "[  ●]" or "[●  ]"
        label_w = @label ? (VisualWidth.width(@label.not_nil!) + 1) : 0
        total_w = Math.min(available_w, switch_w + label_w)
        {Math.max(switch_w, total_w), 1}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0

        @last_x = x
        @last_y = y
        @last_h = 1

        th = current_theme
        glyphs = th.glyphs

        # Colors
        c_on_thumb = @on_thumb_fg || th.accent
        c_on_track = @on_track_fg || th.primary
        c_off_thumb = @off_thumb_fg || th.text_muted
        c_off_track = @off_track_fg || th.border
        c_label = @label_fg || (@disabled ? th.text_muted : th.text)
        c_focus = @focus_border_fg || th.primary

        ch_thumb = @thumb_char || '●'
        ch_track = @track_char || '─'

        bracket_fg = focused? ? c_focus : th.border

        buffer.with_clip(x, y, width, height) do
          # Render Switch Track: "[●   ]" or "[   ●]"
          buffer.put_char(x, y, '[', fg: bracket_fg, bold: focused?) if width > 0
          if @on
            buffer.put_char(x + 1, y, ch_track, fg: c_on_track) if width > 1
            buffer.put_char(x + 2, y, ch_track, fg: c_on_track) if width > 2
            buffer.put_char(x + 3, y, ch_track, fg: c_on_track) if width > 3
            buffer.put_char(x + 4, y, ch_thumb, fg: c_on_thumb, bold: true) if width > 4
          else
            buffer.put_char(x + 1, y, ch_thumb, fg: c_off_thumb) if width > 1
            buffer.put_char(x + 2, y, ch_track, fg: c_off_track) if width > 2
            buffer.put_char(x + 3, y, ch_track, fg: c_off_track) if width > 3
            buffer.put_char(x + 4, y, ch_track, fg: c_off_track) if width > 4
          end
          buffer.put_char(x + 5, y, ']', fg: bracket_fg, bold: focused?) if width > 5

          # Render Label if present
          cur_w = 6
          if lbl = @label
            avail_label_w = Math.max(0, width - cur_w - 1)
            if avail_label_w > 0
              buffer.put_string(x + cur_w + 1, y, lbl, fg: c_label, bold: focused? && !@disabled, max_width: avail_label_w)
              cur_w += 1 + Math.min(avail_label_w, VisualWidth.width(lbl))
            end
          end

          @last_w = Math.min(width, cur_w)
        end
      end
    end
  end
end
