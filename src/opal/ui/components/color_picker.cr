require "../element"
require "../buffer"
require "../../style/color"
require "../../style/border"
require "../../style/visual_width"
require "../../terminal/driver"

module Opal
  module UI
    # Interactive TrueColor 24-bit color picker with RGB channel sliders,
    # live TrueColor preview swatches, hex calculations, and preset palettes.
    class ColorPicker < Control
      property r : Int32
      property g : Int32
      property b : Int32
      property active_channel : Symbol # :red, :green, :blue, :palette
      property palette_cursor : Int32 = 0
      property preset_swatches : Array(Color)
      getter? confirmed : Bool = false

      # Curated designer palette (Catppuccin Mocha, Dracula, TokyoNight, Nord)
      DEFAULT_PALETTE = [
        Color.hex("#F38BA8"), # Flamingo / Red
        Color.hex("#FAB387"), # Peach / Orange
        Color.hex("#F9E2AF"), # Yellow
        Color.hex("#A6E3A1"), # Green
        Color.hex("#94E2D5"), # Teal
        Color.hex("#74C7EC"), # Sapphire
        Color.hex("#89B4FA"), # Blue
        Color.hex("#CBA6F7"), # Mauve / Purple
        Color.hex("#BD93F9"), # Dracula Purple
        Color.hex("#FF79C6"), # Dracula Pink
        Color.hex("#50FA7B"), # Dracula Green
        Color.hex("#88C0D0"), # Nord Frost Cyan
        Color.hex("#81A1C1"), # Nord Blue
        Color.hex("#D08770"), # Nord Orange
        Color.hex("#EBCB8B"), # Nord Yellow
        Color.hex("#FFFFFF"), # Pure White
      ]

      def initialize(
        initial_color : Color = Color.hex("#89B4FA"),
        @active_channel : Symbol = :red,
        presets : Array(Color)? = nil,
      )
        r_u, g_u, b_u = initial_color.to_rgb
        @r = r_u.to_i
        @g = g_u.to_i
        @b = b_u.to_i
        @preset_swatches = presets || DEFAULT_PALETTE
        super()
      end

      def color : Color
        Color.rgb(@r, @g, @b)
      end

      def color=(c : Color) : Nil
        r_u, g_u, b_u = c.to_rgb
        @r = r_u.to_i
        @g = g_u.to_i
        @b = b_u.to_i
      end

      def hex_code : String
        color.to_hex
      end

      def luminance : Float64
        (0.299 * @r + 0.587 * @g + 0.114 * @b) / 255.0
      end

      def next_channel : Nil
        @active_channel = case @active_channel
                          when :red     then :green
                          when :green   then :blue
                          when :blue    then :palette
                          when :palette then :red
                          else               :red
                          end
      end

      def prev_channel : Nil
        @active_channel = case @active_channel
                          when :red     then :palette
                          when :green   then :red
                          when :blue    then :green
                          when :palette then :blue
                          else               :red
                          end
      end

      def adjust_active(delta : Int32) : Nil
        case @active_channel
        when :red
          @r = (@r + delta).clamp(0, 255)
        when :green
          @g = (@g + delta).clamp(0, 255)
        when :blue
          @b = (@b + delta).clamp(0, 255)
        when :palette
          max_idx = Math.min(10, @preset_swatches.size) - 1
          step = delta > 0 ? 1 : -1
          @palette_cursor = (@palette_cursor + step).clamp(0, max_idx)
          select_preset(@palette_cursor)
        end
      end

      def select_preset(idx : Int32) : Nil
        return if @preset_swatches.empty?
        max_idx = Math.min(10, @preset_swatches.size) - 1
        @palette_cursor = idx.clamp(0, max_idx)
        @active_channel = :palette
        self.color = @preset_swatches[@palette_cursor]
      end

      def handle_key(key : Terminal::KeyEvent) : Bool
        case key.name
        when "tab", "down", "ctrl+n"
          next_channel
          true
        when "shift+tab", "up", "ctrl+p"
          prev_channel
          true
        when "left", "h"
          adjust_active(-5)
          true
        when "right", "l"
          adjust_active(5)
          true
        when "-", "["
          adjust_active(-1)
          true
        when "+", "=", "]"
          adjust_active(1)
          true
        when "pageup"
          adjust_active(-25)
          true
        when "pagedown"
          adjust_active(25)
          true
        when "r"
          @active_channel = :red
          true
        when "g"
          @active_channel = :green
          true
        when "b"
          @active_channel = :blue
          true
        when "p"
          @active_channel = :palette
          select_preset(@palette_cursor)
          true
        when "space"
          if @active_channel == :palette
            select_preset(@palette_cursor)
            true
          else
            false
          end
        when "enter"
          if @active_channel == :palette
            select_preset(@palette_cursor)
          end
          @confirmed = true
          true
        else
          if key.name.size == 1 && key.name[0].ascii_number?
            num = key.name.to_i
            idx = num == 0 ? 9 : num - 1
            if idx < @preset_swatches.size
              select_preset(idx)
              return true
            end
          end
          false
        end
      end

      property last_x : Int32 = 0
      property last_y : Int32 = 0
      property last_w : Int32 = 40
      property last_h : Int32 = 14
      property last_slider_x : Int32 = 7
      property last_track_w : Int32 = 16
      property last_red_y : Int32 = 6
      property last_green_y : Int32 = 7
      property last_blue_y : Int32 = 8
      property last_preset_y : Int32 = 10
      property last_preset_start_x : Int32 = 11
      property last_preset_count : Int32 = 10

      @dragging_channel : Symbol? = nil

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        # Convert terminal coordinates (1-indexed) to buffer coordinates (0-indexed)
        # Also tolerate 0-indexed coordinates if passed in test calls
        by = event.y - 1
        bx = event.x - 1

        matched_row : Symbol? = nil
        if by == @last_red_y
          matched_row = :red
        elsif by == @last_green_y
          matched_row = :green
        elsif by == @last_blue_y
          matched_row = :blue
        elsif by == @last_preset_y
          matched_row = :preset
        elsif event.y == @last_red_y
          by = event.y
          bx = event.x
          matched_row = :red
        elsif event.y == @last_green_y
          by = event.y
          bx = event.x
          matched_row = :green
        elsif event.y == @last_blue_y
          by = event.y
          bx = event.x
          matched_row = :blue
        elsif event.y == @last_preset_y
          by = event.y
          bx = event.x
          matched_row = :preset
        end

        case event.button
        when Terminal::MouseButton::WheelUp
          case matched_row
          when :red
            @active_channel = :red
            @r = (@r + 5).clamp(0, 255)
          when :green
            @active_channel = :green
            @g = (@g + 5).clamp(0, 255)
          when :blue
            @active_channel = :blue
            @b = (@b + 5).clamp(0, 255)
          when :preset
            adjust_active(1)
          else
            adjust_active(5)
          end
          true
        when Terminal::MouseButton::WheelDown
          case matched_row
          when :red
            @active_channel = :red
            @r = (@r - 5).clamp(0, 255)
          when :green
            @active_channel = :green
            @g = (@g - 5).clamp(0, 255)
          when :blue
            @active_channel = :blue
            @b = (@b - 5).clamp(0, 255)
          when :preset
            adjust_active(-1)
          else
            adjust_active(-5)
          end
          true
        when Terminal::MouseButton::Left
          if event.action == Terminal::MouseAction::Release
            @dragging_channel = nil
            return true
          end

          active_drag = @dragging_channel
          target_channel = active_drag || matched_row

          case target_channel
          when :preset
            swatch_start_x = @last_preset_start_x
            if bx >= swatch_start_x
              s_idx = (bx - swatch_start_x) // 3
              if s_idx >= 0 && s_idx < Math.min(@last_preset_count, @preset_swatches.size)
                select_preset(s_idx)
                return true
              end
              false
            else
              @active_channel = :palette
              select_preset(@palette_cursor)
              return true
            end
          when :red, :green, :blue
            slider_x = @last_slider_x
            track_w = @last_track_w
            chan = target_channel.not_nil!

            if event.action == Terminal::MouseAction::Press
              @dragging_channel = chan
            end

            @active_channel = chan

            if bx >= slider_x && track_w > 1
              ratio = (bx - slider_x).to_f / (track_w - 1).to_f
              new_val = (ratio.clamp(0.0, 1.0) * 255.0).round.to_i.clamp(0, 255)
              case target_channel
              when :red   then @r = new_val
              when :green then @g = new_val
              when :blue  then @b = new_val
              end
            end
            true
          else
            false
          end
        when Terminal::MouseButton::None
          if (drag_chan = @dragging_channel) && event.action == Terminal::MouseAction::Motion
            slider_x = @last_slider_x
            track_w = @last_track_w
            if track_w > 1
              ratio = (bx - slider_x).to_f / (track_w - 1).to_f
              new_val = (ratio.clamp(0.0, 1.0) * 255.0).round.to_i.clamp(0, 255)
              case drag_chan
              when :red   then @r = new_val
              when :green then @g = new_val
              when :blue  then @b = new_val
              end
            end
            true
          elsif event.action == Terminal::MouseAction::Release
            @dragging_channel = nil
            true
          else
            false
          end
        else
          if event.action == Terminal::MouseAction::Release
            @dragging_channel = nil
          end
          false
        end
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        {Math.min(available_w, 60), Math.min(available_h, 16)}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width < 25 || height < 8

        cur_y = y
        @last_x = x
        @last_y = y
        @last_w = width
        @last_h = height

        # 1. Header Title
        title_str = "🎨 Color Picker & TrueColor Studio"
        buffer.put_string(x, cur_y, title_str, fg: Color.cyan, bold: true)
        cur_y += 1
        buffer.put_string(x, cur_y, "─" * Math.min(width, 50), fg: Color.bright_black)
        cur_y += 1

        # 2. Preview Swatch Box
        current_c = color
        swatch_w = Math.min(width - 4, 38)
        swatch_h = 2

        (0...swatch_h).each do |s_row|
          break if cur_y >= y + height - 2
          (0...swatch_w).each do |s_col|
            buffer.put_char(x + 2 + s_col, cur_y, '█', fg: current_c)
          end
          cur_y += 1
        end

        # Hex, RGB, Luminance Info
        hex_text = "Hex: #{hex_code}"
        rgb_text = "RGB: (#{@r}, #{@g}, #{@b})"
        lum_pct = (luminance * 100).round.to_i
        lum_text = "Luminance: #{lum_pct}%"

        buffer.put_string(x + 2, cur_y, hex_text, fg: Color.bright_white, bold: true)
        buffer.put_string(x + 2 + VisualWidth.width(hex_text) + 2, cur_y, rgb_text, fg: Color.cyan)
        buffer.put_string(x + 2 + VisualWidth.width(hex_text) + VisualWidth.width(rgb_text) + 4, cur_y, lum_text, fg: Color.bright_black)
        cur_y += 2

        # 3. Sliders for Red, Green, Blue
        track_w = (width - 24).clamp(10, 24)
        slider_x = x + 7
        @last_slider_x = slider_x
        @last_track_w = track_w

        render_slider = ->(label : String, val : Int32, channel_sym : Symbol, chan_color : Color) {
          return if cur_y >= y + height - 2
          is_active = (@active_channel == channel_sym)
          cursor_prefix = is_active ? "▶ " : "  "

          buffer.put_string(x, cur_y, cursor_prefix, fg: Color.cyan, bold: true)
          buffer.put_string(x + 2, cur_y, label, fg: is_active ? Color.bright_white : Color.white, bold: is_active)

          # Slider track
          ratio = val / 255.0
          filled_len = (track_w * ratio).round.to_i.clamp(0, track_w)
          empty_len = track_w - filled_len

          buffer.put_string(slider_x, cur_y, "█" * filled_len, fg: chan_color)
          buffer.put_string(slider_x + filled_len, cur_y, "░" * empty_len, fg: Color.bright_black)

          # Value text
          val_str = sprintf("%3d", val)
          buffer.put_string(slider_x + track_w + 2, cur_y, val_str, fg: is_active ? Color.bright_cyan : Color.white, bold: is_active)

          cur_y += 1
        }

        @last_red_y = cur_y
        render_slider.call("[R]", @r, :red, Color.red)
        @last_green_y = cur_y
        render_slider.call("[G]", @g, :green, Color.green)
        @last_blue_y = cur_y
        render_slider.call("[B]", @b, :blue, Color.blue)
        cur_y += 1

        # 4. Preset Palette Swatches
        if cur_y < y + height - 2
          @last_preset_y = cur_y
          is_pal_active = (@active_channel == :palette)
          p_prefix = is_pal_active ? "▶ " : "  "
          buffer.put_string(x, cur_y, p_prefix, fg: Color.cyan, bold: true)
          buffer.put_string(x + 2, cur_y, "Presets: ", fg: is_pal_active ? Color.bright_white : Color.bright_black, bold: is_pal_active)

          swatch_start_x = x + 11
          @last_preset_start_x = swatch_start_x
          @last_preset_count = Math.min(10, @preset_swatches.size)

          @preset_swatches.first(@last_preset_count).each_with_index do |swatch, s_idx|
            col_x = swatch_start_x + (s_idx * 3)
            break if col_x >= x + width - 3

            is_sel = (is_pal_active && s_idx == @palette_cursor)
            if is_sel
              buffer.put_char(col_x, cur_y, '[', fg: Color.cyan, bold: true)
              buffer.put_char(col_x + 1, cur_y, '■', fg: swatch)
              buffer.put_char(col_x + 2, cur_y, ']', fg: Color.cyan, bold: true)
            else
              buffer.put_char(col_x, cur_y, ' ', fg: Color.none)
              buffer.put_char(col_x + 1, cur_y, '■', fg: swatch)
              buffer.put_char(col_x + 2, cur_y, ' ', fg: Color.none)
            end
          end
          cur_y += 2
        end

        # 5. Footer Instructions
        buffer.put_string(x, cur_y, "─" * Math.min(width, 50), fg: Color.bright_black)
        cur_y += 1
        hints = " [Click/Drag] Sliders & Presets   [Tab] Next   [←/→] +/-5   [+/-] 1   [1-9] Preset   [Enter] OK "
        buffer.put_string(x, Math.min(cur_y, buffer.height - 1), hints, fg: Color.bright_black)
      end
    end
  end

  # High-level interactive color picker helper.
  def self.pick_color(
    initial : Color = Color.hex("#89B4FA"),
    driver : Terminal::Driver? = nil,
  ) : Color?
    drv = driver || Terminal.default_driver
    picker = UI::ColorPicker.new(initial)

    render_frame = -> {
      w, h = drv.size
      buf = UI::Buffer.new(w, h)
      picker.render(buf, 0, 0, w, h)
      drv.write(Terminal::Screen::CLEAR_ALL)
      drv.write(Terminal::Screen.move_to(1, 1))
      drv.write(buf.to_s)
      drv.flush
    }

    result : Color? = nil

    drv.raw_mode do
      drv.hide_cursor
      drv.enable_mouse
      render_frame.call

      loop do
        event = drv.read_event
        next unless event
        should_redraw = false

        case event
        when Terminal::KeyEvent
          if event.matches?("escape") || event.matches?("ctrl+c")
            break
          end

          if picker.handle_key(event)
            should_redraw = true
            if picker.confirmed?
              result = picker.color
              break
            end
          end
        when Terminal::MouseEvent
          if picker.handle_mouse(event)
            should_redraw = true
            if picker.confirmed?
              result = picker.color
              break
            end
          end
        end

        render_frame.call if should_redraw
      end
    ensure
      drv.disable_mouse
      drv.show_cursor
    end

    result
  end
end
