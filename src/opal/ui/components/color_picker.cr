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
    class ColorPicker < Element
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
          @palette_cursor = (@palette_cursor + delta).clamp(0, @preset_swatches.size - 1)
          select_preset(@palette_cursor)
        end
      end

      def select_preset(idx : Int32) : Nil
        return if @preset_swatches.empty?
        @palette_cursor = idx.clamp(0, @preset_swatches.size - 1)
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
          true
        when "enter"
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

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        {Math.min(available_w, 60), Math.min(available_h, 16)}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width < 25 || height < 8

        cur_y = y

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

          slider_x = x + 7
          buffer.put_string(slider_x, cur_y, "█" * filled_len, fg: chan_color)
          buffer.put_string(slider_x + filled_len, cur_y, "░" * empty_len, fg: Color.bright_black)

          # Value text
          val_str = sprintf("%3d", val)
          buffer.put_string(slider_x + track_w + 2, cur_y, val_str, fg: is_active ? Color.bright_cyan : Color.white, bold: is_active)

          cur_y += 1
        }

        render_slider.call("[R]", @r, :red, Color.red)
        render_slider.call("[G]", @g, :green, Color.green)
        render_slider.call("[B]", @b, :blue, Color.blue)
        cur_y += 1

        # 4. Preset Palette Swatches
        if cur_y < y + height - 2
          is_pal_active = (@active_channel == :palette)
          p_prefix = is_pal_active ? "▶ " : "  "
          buffer.put_string(x, cur_y, p_prefix, fg: Color.cyan, bold: true)
          buffer.put_string(x + 2, cur_y, "Presets: ", fg: is_pal_active ? Color.bright_white : Color.bright_black, bold: is_pal_active)

          swatch_start_x = x + 11
          @preset_swatches.first(Math.min(10, @preset_swatches.size)).each_with_index do |swatch, s_idx|
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
        hints = " [Tab] Next   [←/→] +/-5   [+/-] 1   [1-9] Preset   [Enter] OK "
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
        end

        render_frame.call if should_redraw
      end
    ensure
      drv.show_cursor
    end

    result
  end
end
