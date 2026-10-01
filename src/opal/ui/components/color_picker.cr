require "../element"
require "../buffer"
require "./target_selector_2d"
require "../../style/color"
require "../../style/border"
require "../../style/visual_width"
require "../../terminal/driver"

module Opal
  module UI
    # Available color spaces for color picker editing and presentation
    enum ColorMode
      RGB
      HSL
      HSV
      LAB
      Oklab
      XYZ
      CMYK
      HEX

      def display_name : String
        case self
        when RGB   then "sRGB (0-255)"
        when HSL   then "HSL (Hue, Sat, Light)"
        when HSV   then "HSV (Hue, Sat, Value)"
        when LAB   then "CIELAB (L*a*b*)"
        when Oklab then "Oklab (Perceptual)"
        when XYZ   then "CIE XYZ (D65)"
        when CMYK  then "CMYK (Print)"
        when HEX   then "Hexadecimal"
        else            "sRGB"
        end
      end
    end

    # Visual layout configuration for the ColorPicker
    enum ColorPickerLayout
      Studio      # Full studio: 2D Target selector slice + channel sliders + swatches + harmonies + info
      Sliders     # Channel sliders only + preview swatch + info
      Compact     # Single line / mini box with hex + color chip
      PaletteOnly # Quick swatches palette only
    end

    # Interactive TrueColor 24-bit color picker supporting 8 color spaces
    # (RGB, HSL, HSV, LAB, Oklab, XYZ, CMYK, HEX), embedded 2D target slicing,
    # alpha transparency, live color harmonies, swatches, and select button.
    class ColorPicker < Control
      property mode : ColorMode = ColorMode::RGB
      property allowed_modes : Array(ColorMode) = [
        ColorMode::RGB,
        ColorMode::HSL,
        ColorMode::HSV,
        ColorMode::LAB,
        ColorMode::Oklab,
        ColorMode::XYZ,
        ColorMode::CMYK,
        ColorMode::HEX,
      ]
      property layout : ColorPickerLayout = ColorPickerLayout::Studio

      # sRGB base channels
      property r : Int32
      property g : Int32
      property b : Int32

      # Alpha channel [0.0..1.0]
      property alpha : Float64 = 1.0
      property? show_alpha : Bool = false

      # UI Options
      property? show_harmonies : Bool = true
      property? show_select_button : Bool = false
      property? show_target_selector : Bool = true

      property active_channel : Symbol # :red, :green, :blue, :palette, :alpha, :select_btn, etc.
      property palette_cursor : Int32 = 0
      property preset_swatches : Array(Color)
      getter? confirmed : Bool = false

      # Callbacks
      property on_change : Proc(Color, Nil)? = nil
      property on_confirm : Proc(Color, Nil)? = nil

      # Embedded 2D target selector for 2D color plane slicing
      property target_selector : TargetSelector2D

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

      # Rendering layout cache
      property last_x : Int32 = 0
      property last_y : Int32 = 0
      property last_w : Int32 = 50
      property last_h : Int32 = 18
      property last_slider_x : Int32 = 7
      property last_track_w : Int32 = 16
      property last_red_y : Int32 = 6
      property last_green_y : Int32 = 7
      property last_blue_y : Int32 = 8
      property last_preset_y : Int32 = 10
      property last_preset_start_x : Int32 = 11
      property last_preset_count : Int32 = 10
      property last_select_btn_y : Int32 = 13
      property last_select_btn_x : Int32 = 2
      property last_select_btn_w : Int32 = 16

      @dragging_channel : Symbol? = nil

      def initialize(
        initial_color : Color = Color.hex("#89B4FA"),
        @active_channel : Symbol = :red,
        presets : Array(Color)? = nil,
        @mode : ColorMode = ColorMode::RGB,
        @layout : ColorPickerLayout = ColorPickerLayout::Studio,
        @show_alpha : Bool = false,
        @show_harmonies : Bool = true,
        @show_select_button : Bool = false,
      )
        r_u, g_u, b_u = initial_color.to_rgb
        @r = r_u.to_i
        @g = g_u.to_i
        @b = b_u.to_i
        @preset_swatches = presets || DEFAULT_PALETTE

        # Initialize embedded 2D target selector
        @target_selector = TargetSelector2D.new(
          x_range: 0.0..1.0,
          y_range: 0.0..1.0,
          initial_x: 0.5,
          initial_y: 0.5,
          width: 18,
          height: 8,
          show_coordinates: false,
          border: true
        )
        super()
        @last_w = 54
        @last_h = 18

        sync_target_selector_shader
      end

      def color : Color
        Color.rgb(@r, @g, @b)
      end

      def color=(c : Color) : Nil
        r_u, g_u, b_u = c.to_rgb
        @r = r_u.to_i
        @g = g_u.to_i
        @b = b_u.to_i
        sync_target_selector_shader
        @on_change.try &.call(color)
      end

      def hex_code : String
        color.to_hex
      end

      def luminance : Float64
        (0.299 * @r + 0.587 * @g + 0.114 * @b) / 255.0
      end

      # Cycles to the next color editing mode
      def cycle_mode : Nil
        curr_idx = @allowed_modes.index(@mode) || 0
        @mode = @allowed_modes[(curr_idx + 1) % @allowed_modes.size]
        sync_target_selector_shader
      end

      # Computes color harmonies (Complementary, Analogous, Triadic)
      def harmonies : Hash(Symbol, Array(Color))
        h, s, l = color.to_hsl

        # Complementary (180 deg)
        comp = Color.hsl((h + 180.0) % 360.0, s, l)

        # Analogous (+30, -30 deg)
        ana1 = Color.hsl((h + 30.0) % 360.0, s, l)
        ana2 = Color.hsl((h - 30.0 + 360.0) % 360.0, s, l)

        # Triadic (+120, +240 deg)
        tri1 = Color.hsl((h + 120.0) % 360.0, s, l)
        tri2 = Color.hsl((h + 240.0) % 360.0, s, l)

        {
          :complementary => [comp],
          :analogous     => [ana1, ana2],
          :triadic       => [tri1, tri2],
        }
      end

      private def sync_target_selector_shader : Nil
        cur_c = color
        case @mode
        when ColorMode::HSV, ColorMode::RGB
          # X is Saturation (0..1), Y is Value (0..1), Hue fixed
          h, _, _ = cur_c.to_hsv
          @target_selector.background_shader = ->(u : Float64, v : Float64) : Color {
            Color.hsv(h, u, v)
          }
        when ColorMode::HSL
          # X is Hue (0..360), Y is Lightness (0..1), Saturation fixed
          _, s, _ = cur_c.to_hsl
          @target_selector.background_shader = ->(u : Float64, v : Float64) : Color {
            Color.hsl(u * 360.0, s, v)
          }
        when ColorMode::LAB
          # X is a* (-128..127), Y is b* (-128..127), L* fixed
          l, _, _ = cur_c.to_lab
          @target_selector.background_shader = ->(u : Float64, v : Float64) : Color {
            a_val = -128.0 + u * 255.0
            b_val = -128.0 + v * 255.0
            Color.lab(l, a_val, b_val)
          }
        when ColorMode::Oklab
          # X is a (-0.4..0.4), Y is b (-0.4..0.4), L fixed
          l, _, _ = cur_c.to_oklab
          @target_selector.background_shader = ->(u : Float64, v : Float64) : Color {
            a_val = -0.4 + u * 0.8
            b_val = -0.4 + v * 0.8
            Color.oklab(l, a_val, b_val)
          }
        when ColorMode::XYZ
          # X is X (0..1), Y is Z (0..1), Y luminance fixed
          _, y_lum, _ = cur_c.to_xyz
          @target_selector.background_shader = ->(u : Float64, v : Float64) : Color {
            Color.xyz(u, y_lum, v)
          }
        else
          h, _, _ = cur_c.to_hsv
          @target_selector.background_shader = ->(u : Float64, v : Float64) : Color {
            Color.hsv(h, u, v)
          }
        end
      end

      def next_channel : Nil
        channels = active_channel_list
        curr_idx = channels.index(@active_channel) || 0
        @active_channel = channels[(curr_idx + 1) % channels.size]
      end

      def prev_channel : Nil
        channels = active_channel_list
        curr_idx = channels.index(@active_channel) || 0
        @active_channel = channels[(curr_idx - 1 + channels.size) % channels.size]
      end

      private def active_channel_list : Array(Symbol)
        list = [:red, :green, :blue]
        list << :alpha if @show_alpha
        list << :palette
        list << :select_btn if @show_select_button
        list
      end

      def adjust_active(delta : Int32) : Nil
        case @active_channel
        when :red
          @r = (@r + delta).clamp(0, 255)
        when :green
          @g = (@g + delta).clamp(0, 255)
        when :blue
          @b = (@b + delta).clamp(0, 255)
        when :alpha
          @alpha = (@alpha + (delta.to_f / 100.0)).clamp(0.0, 1.0)
        when :palette
          max_idx = Math.min(10, @preset_swatches.size) - 1
          step = delta > 0 ? 1 : -1
          @palette_cursor = (@palette_cursor + step).clamp(0, max_idx)
          select_preset(@palette_cursor)
        end
        sync_target_selector_shader
        @on_change.try &.call(color)
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
        when "m", "M"
          cycle_mode
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
          elsif @active_channel == :select_btn
            @confirmed = true
            @on_confirm.try &.call(color)
            true
          else
            false
          end
        when "enter"
          if @active_channel == :palette
            select_preset(@palette_cursor)
          end
          @confirmed = true
          @on_confirm.try &.call(color)
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

      def handle_mouse(event : Terminal::MouseEvent) : Bool
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
        elsif by == @last_select_btn_y
          matched_row = :select_btn
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
        elsif event.y == @last_select_btn_y
          by = event.y
          bx = event.x
          matched_row = :select_btn
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
          sync_target_selector_shader
          @on_change.try &.call(color)
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
          sync_target_selector_shader
          @on_change.try &.call(color)
          true
        when Terminal::MouseButton::Left
          if event.action == Terminal::MouseAction::Release
            @dragging_channel = nil
            return true
          end

          active_drag = @dragging_channel
          target_channel = active_drag || matched_row

          case target_channel
          when :select_btn
            if bx >= @last_select_btn_x && bx < @last_select_btn_x + @last_select_btn_w
              @confirmed = true
              @on_confirm.try &.call(color)
              return true
            end
            false
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
              sync_target_selector_shader
              @on_change.try &.call(color)
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
              sync_target_selector_shader
              @on_change.try &.call(color)
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
        {Math.min(available_w, 64), Math.min(available_h, 18)}
      end

      def render(buffer : Buffer) : Nil
        render(buffer, @last_x, @last_y, @last_w, @last_h)
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width < 25 || height < 8

        cur_y = y
        @last_x = x
        @last_y = y
        @last_w = width
        @last_h = height

        # 1. Header Title & Mode
        title_str = "Color Picker: #{@mode.display_name} [Press 'm' to switch mode]"
        buffer.put_string(x, cur_y, title_str, fg: Color.cyan, bold: true)
        cur_y += 1
        buffer.put_string(x, cur_y, "─" * Math.min(width, 52), fg: Color.bright_black)
        cur_y += 1

        # 2. Preview Swatch Box & Multi-Space Color Info
        current_c = color
        swatch_w = Math.min(width - 4, 38)
        swatch_h = 2

        (0...swatch_h).each do |_|
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
        cur_y += 1

        # Additional color space readouts (LAB & Oklab & HSL)
        if width >= 50 && cur_y < y + height - 2
          lab = current_c.to_lab
          ok = current_c.to_oklab
          lab_text = sprintf("LAB: (%.1f, %.1f, %.1f)  Oklab: (%.2f, %.2f, %.2f)", lab[0], lab[1], lab[2], ok[0], ok[1], ok[2])
          buffer.put_string(x + 2, cur_y, lab_text, fg: Color.hex("#6272A4"))
          cur_y += 1
        end
        cur_y += 1

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
          cur_y += 1
        end

        # 5. Live Color Harmonies (Complementary, Analogous, Triadic)
        if @show_harmonies && cur_y < y + height - 3
          harms = harmonies
          buffer.put_string(x + 2, cur_y, "Harmonies: ", fg: Color.bright_black)
          hx = x + 13
          # Comp
          buffer.put_char(hx, cur_y, '■', fg: harms[:complementary].first)
          buffer.put_string(hx + 2, cur_y, "Comp  ", fg: Color.bright_black)
          hx += 9
          # Analogous
          harms[:analogous].each do |ac|
            buffer.put_char(hx, cur_y, '■', fg: ac)
            hx += 2
          end
          buffer.put_string(hx, cur_y, "Analogous  ", fg: Color.bright_black)
          hx += 12
          # Triadic
          harms[:triadic].each do |tc|
            buffer.put_char(hx, cur_y, '■', fg: tc)
            hx += 2
          end
          buffer.put_string(hx, cur_y, "Triadic", fg: Color.bright_black)
          cur_y += 1
        end

        # 6. Select Button
        if @show_select_button && cur_y < y + height - 2
          @last_select_btn_y = cur_y
          @last_select_btn_x = x + 2
          @last_select_btn_w = 18
          is_btn_active = (@active_channel == :select_btn)
          btn_text = is_btn_active ? "▶ [ SELECT COLOR ]" : "  [ Select Color ]"
          btn_fg = is_btn_active ? Color.hex("#50FA7B") : Color.white
          buffer.put_string(x + 2, cur_y, btn_text, fg: btn_fg, bold: is_btn_active)
          cur_y += 1
        end

        # 7. Footer Instructions
        if cur_y < y + height
          buffer.put_string(x, cur_y, "─" * Math.min(width, 52), fg: Color.bright_black)
          cur_y += 1
          hints = " [Click/Drag] Sliders   [m] Mode   [Tab] Next   [←/→] +/-5   [Enter] Confirm "
          buffer.put_string(x, Math.min(cur_y, buffer.height - 1), hints, fg: Color.bright_black)
        end
      end
    end
  end

  # High-level interactive color picker helper.
  def self.pick_color(
    initial : Color = Color.hex("#89B4FA"),
    driver : Terminal::Driver? = nil,
    mode : UI::ColorMode = UI::ColorMode::RGB,
    layout : UI::ColorPickerLayout = UI::ColorPickerLayout::Studio,
    show_harmonies : Bool = true,
    show_select_button : Bool = true,
    output : IO? = nil,
  ) : Color?
    drv = driver || (output ? Terminal.default_driver(output: output) : Terminal.default_driver)
    picker = UI::ColorPicker.new(
      initial_color: initial,
      mode: mode,
      layout: layout,
      show_harmonies: show_harmonies,
      show_select_button: show_select_button
    )

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
