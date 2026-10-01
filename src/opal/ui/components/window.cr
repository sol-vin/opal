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

      # Manipulable theme styling and character swaps
      property title_fg : Color? = nil
      property border_fg : Color? = nil
      property active_border_fg : Color? = nil
      property inactive_border_fg : Color? = nil
      property drag_border_fg : Color? = nil
      property resize_border_fg : Color? = nil
      property resize_handle_fg : Color? = nil
      property bg : Color? = nil
      property border : Border? = nil
      property close_glyph : String? = nil
      property maximize_glyph : String? = nil
      property minimize_glyph : String? = nil
      property resize_glyph : Char? = nil
      property shadow_fg : Color? = nil
      property shadow_char : Char? = nil

      # Drag and resize callbacks
      property on_drag : Proc(Window, Int32, Int32, Nil)? = nil
      property on_resize : Proc(Window, Int32, Int32, Nil)? = nil

      # Mouse dragging and resizing tracking
      @dragging_title : Bool = false
      @resizing : Bool = false
      @drag_offset_x : Int32 = 0
      @drag_offset_y : Int32 = 0
      @last_render_x : Int32 = 0
      @last_render_y : Int32 = 0

      def dragging? : Bool
        @dragging_title
      end

      def resizing? : Bool
        @resizing
      end

      def on_drag(&block : (Window, Int32, Int32) -> Nil) : self
        @on_drag = block
        self
      end

      def on_resize(&block : (Window, Int32, Int32) -> Nil) : self
        @on_resize = block
        self
      end

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
        title_fg : Color | Symbol | String | Nil = nil,
        border_fg : Color | Symbol | String | Nil = nil,
        active_border_fg : Color | Symbol | String | Nil = nil,
        inactive_border_fg : Color | Symbol | String | Nil = nil,
        bg : Color | Symbol | String | Nil = nil,
        border : Border | Symbol | String | Nil = nil,
        @close_glyph : String? = nil,
        @maximize_glyph : String? = nil,
        @minimize_glyph : String? = nil,
        @resize_glyph : Char? = nil,
      )
        super()
        @minimized = false
        @maximized = false
        @active = true
        @title_fg = title_fg ? Color.from(title_fg) : nil
        @border_fg = border_fg ? Color.from(border_fg) : nil
        @active_border_fg = active_border_fg ? Color.from(active_border_fg) : nil
        @inactive_border_fg = inactive_border_fg ? Color.from(inactive_border_fg) : nil
        @bg = bg ? Color.from(bg) : nil
        @border = border ? Border.from(border) : nil
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

      def minimize! : self
        @minimized = true
        self
      end

      def maximize!(max_w : Int32 = 80, max_h : Int32 = 24) : self
        toggle_maximize(max_w, max_h) unless @maximized
        self
      end

      def restore!(max_w : Int32 = 80, max_h : Int32 = 24) : self
        @minimized = false
        toggle_maximize(max_w, max_h) if @maximized
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
        case event.action
        when Terminal::MouseAction::Press
          if event.button == Terminal::MouseButton::Left
            handle_mouse_press(event.x, event.y)
          else
            false
          end
        when Terminal::MouseAction::Motion
          if @dragging_title || @resizing
            handle_mouse_drag(event.x, event.y)
          else
            false
          end
        when Terminal::MouseAction::Release
          if @dragging_title || @resizing
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
        eff_x = @last_render_x + @x
        eff_y = @last_render_y + @y
        eff_h = @minimized ? 1 : @height

        # Check window hit bounds
        return false unless mx >= eff_x && mx < (eff_x + @width) && my >= eff_y && my < (eff_y + eff_h)

        @active = true

        # Check title bar button clicks (top-right area)
        if my == eff_y
          # Close button [x]
          if @closable && mx >= (eff_x + @width - 4) && mx <= (eff_x + @width - 2)
            close
            return true
          end

          # Maximize button [^]
          if @maximizable && mx >= (eff_x + @width - 8) && mx <= (eff_x + @width - 6)
            toggle_maximize
            return true
          end

          # Minimize button [-]
          if @minimizable && mx >= (eff_x + @width - 12) && mx <= (eff_x + @width - 10)
            toggle_minimize
            return true
          end

          # Otherwise, start dragging title bar
          @dragging_title = true
          @drag_offset_x = mx - eff_x
          @drag_offset_y = my - eff_y
          return true
        end

        # Check bottom-right corner resize handle (generous 2x2 corner area for smooth interaction)
        if @resizable && !@minimized && mx >= (eff_x + @width - 2) && mx < (eff_x + @width) &&
           my >= (eff_y + @height - 2) && my < (eff_y + @height)
          @resizing = true
          return true
        end

        # Forward mouse to client content if content is a Control
        if !@minimized && (ch = @content).is_a?(Control)
          ch.handle_mouse(Terminal::MouseEvent.new(
            x: mx,
            y: my,
            button: Terminal::MouseButton::Left,
            action: Terminal::MouseAction::Press
          ))
        else
          true
        end
      end

      private def handle_mouse_drag(mx : Int32, my : Int32) : Bool
        eff_x = @last_render_x + @x
        eff_y = @last_render_y + @y

        if @dragging_title && !@maximized
          new_x = (mx - @last_render_x) - @drag_offset_x
          new_y = (my - @last_render_y) - @drag_offset_y
          if new_x != @x || new_y != @y
            @x = new_x
            @y = new_y
            @on_drag.try(&.call(self, @x, @y))
          end
          return true
        elsif @resizing && !@maximized && !@minimized
          new_w = Math.max(@min_width, (mx - eff_x) + 1)
          new_h = Math.max(@min_height, (my - eff_y) + 1)
          if new_w != @width || new_h != @height
            @width = new_w
            @height = new_h
            @on_resize.try(&.call(self, @width, @height))
          end
          return true
        else
          false
        end
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        {@width, @height}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        @last_render_x = x
        @last_render_y = y

        # Use window's coordinates relative to container offset
        win_x = x + @x
        win_y = y + @y
        win_w = @width
        win_h = @minimized ? 1 : @height

        return if win_w <= 0 || win_h <= 0

        th = current_theme
        glyphs = th.glyphs
        c_close = @close_glyph || glyphs.window_close
        c_max = @maximize_glyph || glyphs.window_maximize
        c_min = @minimize_glyph || glyphs.window_minimize
        c_resize = @resize_glyph || glyphs.window_resize

        border_style = @border || (@active ? th.window_border : Border.rounded)

        # Dynamic themed border colors reflecting drag/resize state
        border_c = if @dragging_title
                     @drag_border_fg || th.accent
                   elsif @resizing
                     @resize_border_fg || th.warning
                   elsif @border_fg
                     @border_fg.not_nil!
                   elsif @active
                     @active_border_fg || th.primary
                   else
                     @inactive_border_fg || th.border
                   end

        title_c = @title_fg || (@active ? th.accent : th.text)
        bg_c = @bg || th.background
        btn_c = th.text_muted

        if @minimized
          # Render minimized title pill
          min_btn_str = "#{c_min} ]"
          min_btn_w = VisualWidth.width(min_btn_str)
          buffer.put_string(win_x, win_y, "[ ", fg: border_c)
          avail_title = Math.max(0, win_w - min_btn_w - 4)
          display_title = truncate_title(@title, avail_title)
          buffer.put_string(win_x + 2, win_y, display_title, fg: title_c, bold: true, max_width: avail_title)
          btn_x = Math.max(win_x + 2, win_x + win_w - min_btn_w - 1)
          buffer.put_string(btn_x, win_y, min_btn_str, fg: border_c)
          return
        end

        # 1. Drop shadow for 3D depth
        sh_c = @shadow_fg || Color.rgb(40, 40, 40)
        sh_ch = @shadow_char || '░'
        Graphics::Primitives2D.draw_shadow(buffer, win_x, win_y, win_w, win_h, shadow_char: sh_ch, fg: sh_c)

        # 2. Solid background fill inside window
        Graphics::Primitives2D.fill_rect(buffer, win_x, win_y, win_w, win_h, ' ', fg: Color.none, bg: bg_c)

        # 3. Window Border (themed active / dragging / resizing)
        Graphics::Primitives2D.draw_rect(buffer, win_x, win_y, win_w, win_h, border: border_style, fg: border_c)

        # 4. Header Buttons & Title (placed from right to left to avoid collision)
        btn_offset = win_x + win_w - 2

        # Draw buttons if space permits
        show_close = @closable && (btn_offset - VisualWidth.width(c_close) >= win_x + 3)
        if show_close
          w = VisualWidth.width(c_close)
          buffer.put_string(btn_offset - w, win_y, c_close, fg: th.danger, bold: true)
          btn_offset -= (w + 1)
        end

        show_max = @maximizable && (btn_offset - VisualWidth.width(c_max) >= win_x + 3)
        if show_max
          w = VisualWidth.width(c_max)
          buffer.put_string(btn_offset - w, win_y, c_max, fg: btn_c)
          btn_offset -= (w + 1)
        end

        show_min = @minimizable && (btn_offset - VisualWidth.width(c_min) >= win_x + 3)
        if show_min
          w = VisualWidth.width(c_min)
          buffer.put_string(btn_offset - w, win_y, c_min, fg: btn_c)
          btn_offset -= (w + 1)
        end

        # Title: clamp strictly to space between left border (win_x + 2) and leftmost button (btn_offset)
        title_start_x = win_x + 2
        avail_title_w = Math.max(0, (btn_offset - 1) - title_start_x)
        if !@title.empty? && avail_title_w > 0
          display_title = if avail_title_w > 2
                            " #{truncate_title(@title, avail_title_w - 2)} "
                          else
                            truncate_title(@title, avail_title_w)
                          end
          buffer.put_string(title_start_x, win_y, display_title, fg: title_c, bold: true, max_width: avail_title_w)
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

        # 6. Themed resize handle glyph at bottom-right corner if resizable
        if @resizable && !@maximized
          resize_c = @resize_handle_fg || (@resizing ? th.accent : border_c)
          buffer.put_char(win_x + win_w - 1, win_y + win_h - 1, c_resize, fg: resize_c, bold: @resizing)
        end
      end

      private def truncate_title(text : String, max_w : Int32) : String
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
