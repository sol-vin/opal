require "../control"
require "../../style/color"
require "../../style/visual_width"

module Opal
  module UI
    # Focusable, interactive Button component supporting styles (:primary, :secondary,
    # :outline, :danger, :success, :ghost), toggle modes, icons, keyboard shortcuts,
    # and mouse clicks.
    class Button < Control
      property label : String
      property icon : String?
      property variant : Symbol
      property? toggle : Bool
      property? active : Bool
      property? disabled : Bool
      property shortcut_char : Char?
      property on_click : Proc(Button, Nil)?

      # Manipulable theme properties
      property fg : Color? = nil
      property bg : Color? = nil
      property hover_fg : Color? = nil
      property hover_bg : Color? = nil
      property active_fg : Color? = nil
      property active_bg : Color? = nil
      property border_fg : Color? = nil
      property border_style : Border? = nil

      # Internal render coordinates for mouse hit testing
      @last_x : Int32 = 0
      @last_y : Int32 = 0
      @last_w : Int32 = 0
      @last_h : Int32 = 0

      def initialize(
        @label : String,
        @icon : String? = nil,
        @variant : Symbol = :primary,
        @toggle : Bool = false,
        @active : Bool = false,
        @disabled : Bool = false,
        @shortcut_char : Char? = nil,
        @on_click : Proc(Button, Nil)? = nil,
      )
        super()
        @toggle = true if @variant == :toggle
      end

      def on_click(&block : Button -> Nil) : self
        @on_click = block
        self
      end

      def self.new(
        label : String,
        icon : String? = nil,
        variant : Symbol = :primary,
        toggle : Bool = false,
        active : Bool = false,
        disabled : Bool = false,
        shortcut_char : Char? = nil,
        &block : Button -> Nil
      ) : Button
        new(
          label: label,
          icon: icon,
          variant: variant,
          toggle: toggle,
          active: active,
          disabled: disabled,
          shortcut_char: shortcut_char,
          on_click: block
        )
      end

      # Triggers a button activation/click
      def click : self
        return self if @disabled
        if @toggle
          @active = !@active
        end
        @on_click.try(&.call(self))
        self
      end

      def handle_key(key : Terminal::KeyEvent) : Bool
        return false if @disabled

        if (key.name == "enter" || key.name == "return" || key.name == "space" || key.char == ' ')
          click
          true
        elsif sc = @shortcut_char
          if key.char && key.char.not_nil!.downcase == sc.downcase
            click
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
          if event.x >= @last_x && event.x < (@last_x + @last_w) &&
             event.y >= @last_y && event.y < (@last_y + @last_h)
            click
            true
          else
            false
          end
        else
          false
        end
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        icon_w = @icon ? VisualWidth.width(@icon.not_nil!) + 1 : 0
        text_w = icon_w + VisualWidth.width(@label) + 4 # [  ]
        {Math.min(text_w, available_w), 1}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0
        @last_x = x
        @last_y = y
        @last_w = width
        @last_h = 1

        fg, bg = button_colors

        # Truncate label if button text exceeds width
        display_label = @label
        raw_w = VisualWidth.width(@label) + (@icon ? VisualWidth.width(@icon.not_nil!) + 1 : 0) + 4
        if raw_w > width && width > 4
          avail_lbl = Math.max(1, width - (@icon ? VisualWidth.width(@icon.not_nil!) + 1 : 0) - 5)
          display_label = truncate_text(@label, avail_lbl)
        end

        btn_text = String.build do |io|
          io << "["
          io << " "
          if ic = @icon
            io << ic << " "
          end
          io << display_label
          io << " "
          io << "]"
        end

        # Center or left-align within width
        actual_w = VisualWidth.width(btn_text)
        draw_x = x + Math.max(0, (width - actual_w) // 2)

        buffer.put_string(
          draw_x, y, btn_text,
          fg: fg, bg: bg,
          bold: focused? || @active,
          reverse: focused? && !@active,
          max_width: width
        )
      end

      def effective_fg : Color
        button_colors[0]
      end

      def effective_bg : Color
        button_colors[1]
      end

      protected def button_colors : {Color, Color}
        theme = current_theme
        return {theme.text_muted, Color.none} if @disabled

        if @active
          eff_fg = @active_fg || @fg
          eff_bg = @active_bg || @bg
          if eff_fg || eff_bg
            return {eff_fg || Color.bright_white, eff_bg || theme.accent}
          end
        elsif @fg || @bg
          return {@fg || theme.text, @bg || Color.none}
        end

        case @variant
        when :primary
          if @active
            {Color.bright_white, theme.accent}
          else
            {theme.primary, Color.none}
          end
        when :secondary
          if @active
            {Color.bright_white, theme.surface}
          else
            {theme.secondary, Color.none}
          end
        when :danger
          if @active
            {Color.bright_white, theme.danger}
          else
            {theme.danger, Color.none}
          end
        when :success
          if @active
            {Color.bright_white, theme.success}
          else
            {theme.success, Color.none}
          end
        when :outline
          {theme.text, Color.none}
        else # :ghost
          {theme.text_muted, Color.none}
        end
      end

      private def truncate_text(text : String, max_w : Int32) : String
        return "" if max_w <= 0
        return text if VisualWidth.width(text) <= max_w
        return "…" if max_w == 1

        avail = max_w - 1
        res = IO::Memory.new
        cur_w = 0
        text.each_char do |ch|
          cw = VisualWidth.char_width(ch)
          break if cur_w + cw > avail
          res << ch
          cur_w += cw
        end
        res << "…"
        res.to_s
      end
    end
  end
end
