require "../control"
require "../../style/color"
require "../../style/border"
require "../../style/visual_width"
require "../../graphics/primitives_2d"

module Opal
  module UI
    # Movable, resizable floating window container with title bar, minimize/maximize/close
    # buttons, drop shadow depth, and strict client area content clipping.
    class Window < Control
      property title : String
      property x : Int32
      property y : Int32
      property width : Int32
      property height : Int32
      property min_width : Int32
      property min_height : Int32
      property? closable : Bool
      property? minimizable : Bool
      property? maximizable : Bool
      property? resizable : Bool
      property? minimized : Bool
      property? maximized : Bool
      property? active : Bool
      property content : Element?
      property on_close : Proc(Window, Nil)?
      property on_minimize : Proc(Window, Nil)?
      property on_maximize : Proc(Window, Nil)?

      # State preservation for maximize / restore
      @saved_x : Int32 = 0
      @saved_y : Int32 = 0
      @saved_w : Int32 = 0
      @saved_h : Int32 = 0

      # Mouse dragging and resizing tracking
      @dragging_title : Bool = false
      @resizing : Bool = false
      @drag_offset_x : Int32 = 0
      @drag_offset_y : Int32 = 0

      def initialize(
        @title : String,
        @x : Int32 = 2,
        @y : Int32 = 2,
        @width : Int32 = 40,
        @height : Int32 = 12,
        @min_width : Int32 = 18,
        @min_height : Int32 = 5,
        @closable : Bool = true,
        @minimizable : Bool = true,
        @maximizable : Bool = true,
        @resizable : Bool = true,
        @content : Element? = nil,
        @on_close : Proc(Window, Nil)? = nil,
      )
        super()
        @minimized = false
        @maximized = false
        @active = true
      end

      # Closes the window and triggers callback
      def close : self
        @on_close.try(&.call(self))
        self
      end

      # Toggles window minimize state
      def toggle_minimize : self
        @minimized = !@minimized
        @on_minimize.try(&.call(self))
        self
      end

      # Toggles window maximize state
      def toggle_maximize(max_w : Int32 = 80, max_h : Int32 = 24) : self
        if @maximized
          @x = @saved_x
          @y = @saved_y
          @width = @saved_w
          @height = @saved_h
          @maximized = false
        else
          @saved_x = @x
          @saved_y = @y
          @saved_w = @width
          @saved_h = @height
          @x = 0
          @y = 0
          @width = max_w
          @height = max_h
          @maximized = true
        end
        @on_maximize.try(&.call(self))
        self
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        case event.button
        when Terminal::MouseButton::Left
          case event.action
          when Terminal::MouseAction::Press
            handle_mouse_press(event.x, event.y)
          when Terminal::MouseAction::Motion
            handle_mouse_drag(event.x, event.y)
          when Terminal::MouseAction::Release
            @dragging_title = false
            @resizing = false
            true
          else
            false
          end
        else
          false
        end
      end

      private def handle_mouse_press(mx : Int32, my : Int32) : Bool
        # Check window hit bounds
        eff_h = @minimized ? 1 : @height
        return false unless mx >= @x && mx < (@x + @width) && my >= @y && my < (@y + eff_h)

        @active = true

        # Check title bar button clicks (top-right area)
        if my == @y
          # Close button [x]
          if @closable && mx >= (@x + @width - 4) && mx <= (@x + @width - 2)
            close
            return true
          end

          # Maximize button [^]
          if @maximizable && mx >= (@x + @width - 8) && mx <= (@x + @width - 6)
            toggle_maximize
            return true
          end

          # Minimize button [-]
          if @minimizable && mx >= (@x + @width - 12) && mx <= (@x + @width - 10)
            toggle_minimize
            return true
          end

          # Otherwise, start dragging title bar
          @dragging_title = true
          @drag_offset_x = mx - @x
          @drag_offset_y = my - @y
          return true
        end

        # Check bottom-right corner resize handle
        if @resizable && !@minimized && mx >= (@x + @width - 2) && my >= (@y + @height - 2)
          @resizing = true
          return true
        end

        true
      end

      private def handle_mouse_drag(mx : Int32, my : Int32) : Bool
        if @dragging_title && !@maximized
          @x = mx - @drag_offset_x
          @y = my - @drag_offset_y
          return true
        elsif @resizing && !@maximized && !@minimized
          new_w = mx - @x + 1
          new_h = my - @y + 1
          @width = Math.max(@min_width, new_w)
          @height = Math.max(@min_height, new_h)
          return true
        else
          false
        end
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        {@width, @height}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        # Use window's internal coordinates and dimensions
        win_x = @x
        win_y = @y
        win_w = @width
        win_h = @minimized ? 1 : @height

        return if win_w <= 0 || win_h <= 0

        theme = Theme.current
        border_c = @active ? theme.primary : theme.border
        title_c = @active ? theme.accent : theme.text
        btn_c = theme.text_muted

        if @minimized
          # Render minimized title pill
          buffer.put_string(win_x, win_y, "[ ", fg: border_c)
          buffer.put_string(win_x + 2, win_y, @title, fg: title_c, bold: true)
          buffer.put_string(win_x + win_w - 6, win_y, "[-] ]", fg: border_c)
          return
        end

        # 1. Drop shadow for 3D depth
        Graphics::Primitives2D.draw_shadow(buffer, win_x, win_y, win_w, win_h)

        # 2. Solid background fill inside window
        Graphics::Primitives2D.fill_rect(buffer, win_x, win_y, win_w, win_h, ' ', fg: Color.none, bg: theme.background)

        # 3. Window Border
        border_style = @active ? Border.double : Border.rounded
        Graphics::Primitives2D.draw_rect(buffer, win_x, win_y, win_w, win_h, border: border_style, fg: border_c)

        # 4. Title & Header Buttons
        title_str = " #{@title} "
        buffer.put_string(win_x + 2, win_y, title_str, fg: title_c, bold: true)

        # Draw buttons on title bar: [-] [^] [x]
        btn_offset = win_x + win_w - 2
        if @closable
          buffer.put_string(btn_offset - 3, win_y, "[x]", fg: theme.danger, bold: true)
          btn_offset -= 4
        end
        if @maximizable
          buffer.put_string(btn_offset - 3, win_y, "[^]", fg: btn_c)
          btn_offset -= 4
        end
        if @minimizable
          buffer.put_string(btn_offset - 3, win_y, "[-]", fg: btn_c)
        end

        # 5. Client area clipping & Content rendering
        if child = @content
          client_x = win_x + 1
          client_y = win_y + 1
          client_w = Math.max(0, win_w - 2)
          client_h = Math.max(0, win_h - 2)

          buffer.with_clip(client_x, client_y, client_w, client_h) do
            child.render(buffer, client_x, client_y, client_w, client_h)
          end
        end

        # 6. Resize handle glyph at bottom-right corner if resizable
        if @resizable && !@maximized
          buffer.put_char(win_x + win_w - 1, win_y + win_h - 1, '◢', fg: border_c)
        end
      end
    end
  end
end
