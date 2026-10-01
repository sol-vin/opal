require "../control"
require "../../style/color"
require "../../style/visual_width"
require "../../style/theme"

module Opal
  module UI
    # Interactive checkbox widget supporting keyboard (Space/Enter) toggle,
    # mouse click hit-testing, customizable glyphs, and theming.
    class Checkbox < Control
      property label : String?
      property? checked : Bool
      property? disabled : Bool
      property on_change : Proc(Bool, Nil)?

      # Customizable glyphs and styling
      property checked_glyph : String? = nil
      property unchecked_glyph : String? = nil
      property box_fg : Color? = nil
      property box_bg : Color? = nil
      property label_fg : Color? = nil
      property checked_fg : Color? = nil

      # Cached layout coordinates for mouse interaction
      @last_x : Int32 = 0
      @last_y : Int32 = 0
      @last_w : Int32 = 0
      @last_h : Int32 = 1

      def initialize(
        @label : String? = nil,
        @checked : Bool = false,
        @disabled : Bool = false,
        @on_change : Proc(Bool, Nil)? = nil,
      )
        super()
      end

      def self.new(
        label : String? = nil,
        checked : Bool = false,
        disabled : Bool = false,
        &block : Bool -> Nil
      ) : Checkbox
        new(label: label, checked: checked, disabled: disabled, on_change: block)
      end

      def on_change(&block : Bool -> Nil) : self
        @on_change = block
        self
      end

      def toggle : self
        return self if @disabled
        @checked = !@checked
        @on_change.try(&.call(@checked))
        self
      end

      def checked=(val : Bool)
        return if @checked == val
        @checked = val
        @on_change.try(&.call(@checked))
      end

      def handle_key(event : Terminal::KeyEvent) : Bool
        return false if @disabled

        case event.name
        when "space", " ", "enter", "return"
          toggle
          true
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
        glyph_str = @checked ? (@checked_glyph || "[x]") : (@unchecked_glyph || "[ ]")
        box_w = VisualWidth.width(glyph_str)
        lbl_w = @label ? (VisualWidth.width(@label.not_nil!) + 1) : 0
        total_w = Math.min(available_w, box_w + lbl_w)
        {Math.max(box_w, total_w), 1}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0

        @last_x = x
        @last_y = y
        @last_w = width
        @last_h = 1

        th = current_theme
        glyph = if @checked
                  @checked_glyph || "[x]"
                else
                  @unchecked_glyph || "[ ]"
                end

        glyph_w = VisualWidth.width(glyph)

        b_fg = if @disabled
                 th.text_muted
               elsif @checked
                 @checked_fg || @box_fg || th.accent
               else
                 @box_fg || th.text_muted
               end

        b_bg = @box_bg || Color.none
        l_fg = @disabled ? th.text_muted : (@label_fg || th.text)

        buffer.put_string(x, y, glyph, fg: b_fg, bg: b_bg, bold: @checked)

        if lbl = @label
          avail_l = Math.max(0, width - glyph_w - 1)
          if avail_l > 0
            buffer.put_string(x + glyph_w + 1, y, lbl, fg: l_fg, max_width: avail_l)
          end
        end
      end
    end
  end
end
