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

        btn_text = String.build do |io|
          io << "["
          io << " "
          if ic = @icon
            io << ic << " "
          end
          io << @label
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

      private def button_colors : {Color, Color}
        theme = Theme.current
        return {theme.text_muted, Color.none} if @disabled

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
    end
  end
end
