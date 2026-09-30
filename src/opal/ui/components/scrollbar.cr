require "../control"
require "../../style/color"

module Opal
  module UI
    # Focusable, interactive ScrollBar component supporting Vertical and Horizontal
    # orientations, proportional thumb sizing, arrow stepper buttons, mouse dragging,
    # and keyboard paging navigation.
    class ScrollBar < Control
      enum Orientation
        Vertical
        Horizontal
      end

      property orientation : Orientation
      property min_value : Int32
      property max_value : Int32
      property value : Int32
      property page_size : Int32
      property? show_arrows : Bool
      property on_change : Proc(Int32, Nil)?

      # Rendering & hit-testing state
      @render_x : Int32 = 0
      @render_y : Int32 = 0
      @render_w : Int32 = 0
      @render_h : Int32 = 0
      @track_start : Int32 = 0
      @track_length : Int32 = 0
      @thumb_start : Int32 = 0
      @thumb_length : Int32 = 0
      @dragging : Bool = false

      def initialize(
        @orientation : Orientation = Orientation::Vertical,
        @min_value : Int32 = 0,
        @max_value : Int32 = 100,
        @value : Int32 = 0,
        @page_size : Int32 = 10,
        @show_arrows : Bool = true,
        @on_change : Proc(Int32, Nil)? = nil,
      )
        super()
        clamp_value
      end

      def on_change(&block : Int32 -> Nil) : self
        @on_change = block
        self
      end

      def self.new(
        orientation : Orientation = Orientation::Vertical,
        min_value : Int32 = 0,
        max_value : Int32 = 100,
        value : Int32 = 0,
        page_size : Int32 = 10,
        show_arrows : Bool = true,
        &block : Int32 -> Nil
      ) : ScrollBar
        new(
          orientation: orientation,
          min_value: min_value,
          max_value: max_value,
          value: value,
          page_size: page_size,
          show_arrows: show_arrows,
          on_change: block
        )
      end

      def set_value(new_val : Int32) : self
        old_val = @value
        @value = new_val.clamp(@min_value, @max_value)
        if old_val != @value
          @on_change.try(&.call(@value))
        end
        self
      end

      def scroll(delta : Int32) : self
        set_value(@value + delta)
      end

      private def clamp_value : Nil
        if @max_value < @min_value
          @max_value = @min_value
        end
        @value = @value.clamp(@min_value, @max_value)
      end

      def handle_key(key : Terminal::KeyEvent) : Bool
        case key.name
        when "up", "left"
          scroll(-1)
          true
        when "down", "right"
          scroll(1)
          true
        when "pageup"
          scroll(-@page_size)
          true
        when "pagedown"
          scroll(@page_size)
          true
        when "home"
          set_value(@min_value)
          true
        when "end"
          set_value(@max_value)
          true
        else
          false
        end
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        case event.button
        when Terminal::MouseButton::Left
          case event.action
          when Terminal::MouseAction::Press
            handle_press(event.x, event.y)
          when Terminal::MouseAction::Motion
            if @dragging
              handle_drag(event.x, event.y)
              true
            else
              false
            end
          when Terminal::MouseAction::Release
            @dragging = false
            true
          else
            false
          end
        when Terminal::MouseButton::WheelUp
          scroll(-1)
          true
        when Terminal::MouseButton::WheelDown
          scroll(1)
          true
        else
          false
        end
      end

      private def handle_press(mx : Int32, my : Int32) : Bool
        if @orientation == Orientation::Vertical
          return false unless mx == @render_x && my >= @render_y && my < (@render_y + @render_h)

          rel_y = my - @render_y
          if @show_arrows && rel_y == 0
            scroll(-1)
            return true
          elsif @show_arrows && rel_y == @render_h - 1
            scroll(1)
            return true
          else
            track_idx = @show_arrows ? (rel_y - 1) : rel_y
            if track_idx < @thumb_start
              scroll(-@page_size)
              return true
            elsif track_idx >= (@thumb_start + @thumb_length)
              scroll(@page_size)
              return true
            else
              @dragging = true
              return true
            end
          end
        else
          return false unless my == @render_y && mx >= @render_x && mx < (@render_x + @render_w)

          rel_x = mx - @render_x
          if @show_arrows && rel_x == 0
            scroll(-1)
            return true
          elsif @show_arrows && rel_x == @render_w - 1
            scroll(1)
            return true
          else
            track_idx = @show_arrows ? (rel_x - 1) : rel_x
            if track_idx < @thumb_start
              scroll(-@page_size)
              return true
            elsif track_idx >= (@thumb_start + @thumb_length)
              scroll(@page_size)
              return true
            else
              @dragging = true
              return true
            end
          end
        end
      end

      private def handle_drag(mx : Int32, my : Int32) : Nil
        return if @track_length <= @thumb_length
        track_pos = if @orientation == Orientation::Vertical
                      my - @render_y - (@show_arrows ? 1 : 0)
                    else
                      mx - @render_x - (@show_arrows ? 1 : 0)
                    end

        ratio = track_pos.to_f / (@track_length - @thumb_length).to_f
        new_val = @min_value + (ratio * (@max_value - @min_value)).round.to_i
        set_value(new_val)
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        if @orientation == Orientation::Vertical
          {1, available_h}
        else
          {available_w, 1}
        end
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0
        @render_x = x
        @render_y = y
        @render_w = width
        @render_h = height

        theme = Theme.current
        arrow_fg = focused? ? theme.primary : theme.text_muted
        track_fg = theme.border
        thumb_fg = focused? ? theme.accent : theme.primary

        range = Math.max(1, @max_value - @min_value)

        if @orientation == Orientation::Vertical
          total_len = height
          arrow_offset = @show_arrows ? 1 : 0
          @track_length = Math.max(1, total_len - (arrow_offset * 2))

          # Calculate proportional thumb length
          thumb_fraction = @page_size.to_f / (range + @page_size).to_f
          @thumb_length = (thumb_fraction * @track_length).round.to_i.clamp(1, @track_length)

          val_offset = (@value - @min_value).to_f / range.to_f
          available_slack = Math.max(0, @track_length - @thumb_length)
          @thumb_start = (val_offset * available_slack).round.to_i

          # 1. Top arrow
          buffer.put_char(x, y, '▲', fg: arrow_fg) if @show_arrows

          # 2. Track & Thumb
          (0...@track_length).each do |t_idx|
            cur_y = y + arrow_offset + t_idx
            is_thumb = (t_idx >= @thumb_start) && (t_idx < @thumb_start + @thumb_length)
            char = is_thumb ? '█' : '░'
            fg = is_thumb ? thumb_fg : track_fg
            buffer.put_char(x, cur_y, char, fg: fg)
          end

          # 3. Bottom arrow
          buffer.put_char(x, y + total_len - 1, '▼', fg: arrow_fg) if @show_arrows
        else
          total_len = width
          arrow_offset = @show_arrows ? 1 : 0

          @track_length = Math.max(1, total_len - (arrow_offset * 2))

          thumb_fraction = @page_size.to_f / (range + @page_size).to_f
          @thumb_length = (thumb_fraction * @track_length).round.to_i.clamp(1, @track_length)

          val_offset = (@value - @min_value).to_f / range.to_f
          available_slack = Math.max(0, @track_length - @thumb_length)
          @thumb_start = (val_offset * available_slack).round.to_i

          # 1. Left arrow
          buffer.put_char(x, y, '<', fg: arrow_fg) if @show_arrows

          # 2. Track & Thumb
          (0...@track_length).each do |t_idx|
            cur_x = x + arrow_offset + t_idx
            is_thumb = (t_idx >= @thumb_start) && (t_idx < @thumb_start + @thumb_length)
            char = is_thumb ? '█' : '░'
            fg = is_thumb ? thumb_fg : track_fg
            buffer.put_char(cur_x, y, char, fg: fg)
          end

          # 3. Right arrow
          buffer.put_char(x + total_len - 1, y, '>', fg: arrow_fg) if @show_arrows
        end
      end
    end
  end
end
