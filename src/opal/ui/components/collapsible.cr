require "../control"
require "../../style/color"
require "../../style/visual_width"
require "./box"

module Opal
  module UI
    # Accordion collapsible container inspired by Python Textual's Collapsible.
    # Features a clickable header with expandable chevron (▶ / ▼),
    # nested child container, keyboard and mouse toggle, and border styling.
    class Collapsible < Control
      property title : String
      property child : Element?
      property? collapsed : Bool
      property? disabled : Bool
      property on_toggle : Proc(Bool, Nil)?

      # Manipulable styling
      property header_fg : Color? = nil
      property header_bg : Color? = nil
      property chevron_fg : Color? = nil
      property border_fg : Color? = nil
      property open_chevron : String? = nil
      property closed_chevron : String? = nil

      def children : Array(Element)
        if c = @child
          [c]
        else
          [] of Element
        end
      end

      # Header hit detection
      @last_header_x : Int32 = 0
      @last_header_y : Int32 = 0
      @last_header_w : Int32 = 0
      @last_header_h : Int32 = 1

      def initialize(
        @title : String,
        @child : Element? = nil,
        @collapsed : Bool = true,
        @disabled : Bool = false,
        @on_toggle : Proc(Bool, Nil)? = nil,
      )
        super()
      end

      def self.new(
        title : String,
        collapsed : Bool = true,
        disabled : Bool = false,
        &block : Collapsible -> Nil
      ) : Collapsible
        c = new(title: title, collapsed: collapsed, disabled: disabled)
        block.call(c)
        c
      end

      def on_toggle(&block : Bool -> Nil) : self
        @on_toggle = block
        self
      end

      def toggle : self
        return self if @disabled
        @collapsed = !@collapsed
        @on_toggle.try(&.call(@collapsed))
        self
      end

      def expand : self
        if @collapsed
          @collapsed = false
          @on_toggle.try(&.call(@collapsed))
        end
        self
      end

      def collapse : self
        if !@collapsed
          @collapsed = true
          @on_toggle.try(&.call(@collapsed))
        end
        self
      end

      def handle_key(event : Terminal::KeyEvent) : Bool
        return false if @disabled

        case event.name
        when "space", " ", "enter", "return"
          toggle
          true
        when "left"
          if !@collapsed
            collapse
            true
          else
            false
          end
        when "right"
          if @collapsed
            expand
            true
          else
            false
          end
        else
          # Forward to child if open and child is a Control
          if !@collapsed && (ch = @child).is_a?(Control)
            ch.handle_key(event)
          else
            false
          end
        end
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        return false if @disabled

        if event.button == Terminal::MouseButton::Left && event.action == Terminal::MouseAction::Press
          if event.x >= @last_header_x && event.x < @last_header_x + @last_header_w &&
             event.y >= @last_header_y && event.y < @last_header_y + @last_header_h
            toggle
            return true
          end
        end

        # Forward mouse to child if open and child is a Control
        if !@collapsed && (ch = @child).is_a?(Control)
          ch.handle_mouse(event)
        else
          false
        end
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        chevron_len = 3
        header_w = VisualWidth.width(@title) + chevron_len + 2
        return {Math.min(available_w, header_w), 1} if @collapsed || @child.nil?

        if ch = @child
          ch_w, ch_h = ch.preferred_size(Math.max(0, available_w - 2), Math.max(0, available_h - 2))
          total_w = Math.max(header_w, ch_w + 2)
          total_h = 1 + ch_h + 1
          {Math.min(available_w, total_w), Math.min(available_h, total_h)}
        else
          {Math.min(available_w, header_w), 1}
        end
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0

        @last_header_x = x
        @last_header_y = y
        @last_header_w = width
        @last_header_h = 1

        th = current_theme
        glyphs = th.glyphs

        c_chev = @chevron_fg || (focused? ? th.accent : th.primary)
        c_title = @header_fg || (@disabled ? th.text_muted : th.text)
        c_border = @border_fg || th.border
        c_bg = @header_bg || Color.none

        chev = if @collapsed
                 @closed_chevron || "▶"
               else
                 @open_chevron || "▼"
               end

        # 1. Render Header line
        header_text = "#{chev} #{@title}"
        buffer.put_string(
          x, y, header_text,
          fg: c_title,
          bg: c_bg,
          bold: focused? || !@collapsed,
          underline: focused?,
          max_width: width
        )

        # Right-side line filler
        used_w = VisualWidth.width(header_text)
        if used_w + 2 < width
          fill_len = width - used_w - 1
          buffer.put_string(x + used_w + 1, y, "─" * fill_len, fg: c_border, max_width: fill_len)
        end

        return if @collapsed || @child.nil? || height <= 1

        # 2. Render Expanded Child container
        content_y = y + 1
        content_h = height - 1
        content_w = Math.max(0, width - 2)

        # Draw left indentation line
        (0...content_h).each do |cy|
          buffer.put_char(x, content_y + cy, '│', fg: c_border)
        end

        if (ch = @child) && content_w > 0 && content_h > 0
          buffer.with_clip(x + 2, content_y, content_w, content_h) do
            ch.render(buffer, x + 2, content_y, content_w, content_h)
          end
        end
      end
    end
  end
end
