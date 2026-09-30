require "./pass"
require "../style/color"

module Opal
  module Shader
    # Built-in procedural Matrix digital rain shader pass
    class MatrixPass < Pass
      property speed : Float64
      property density : Float64
      property lead_color : Color
      property trail_color : Color
      property? preserve_text : Bool

      MATRIX_CHARS = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F', 'X', 'Z', '$', '#', '@', '%', '&', '*', '+', '-', '=']

      def initialize(
        region : Rect? = nil,
        @speed : Float64 = 1.0,
        @density : Float64 = 0.2,
        lead_color : Color | Symbol | String = :bright_white,
        trail_color : Color | Symbol | String = :green,
        @preserve_text : Bool = true,
      )
        super(region)
        @lead_color = Color.from(lead_color)
        @trail_color = Color.from(trail_color)
      end

      def apply(source : UI::Buffer, target : UI::Buffer, time : Float64, frame : UInt64) : Nil
        return unless @enabled

        rx = @region.try(&.x) || 0
        ry = @region.try(&.y) || 0
        rw = @region.try(&.width) || source.width
        rh = @region.try(&.height) || source.height

        rx = rx.clamp(0, source.width)
        ry = ry.clamp(0, source.height)
        rw = rw.clamp(0, source.width - rx)
        rh = rh.clamp(0, source.height - ry)

        (rx...(rx + rw)).each do |x|
          col_seed = (x.to_i64 &* 1234567_i64) ^ 891011_i64
          col_speed = @speed * (0.8 + ((col_seed % 50).to_f / 100.0))
          col_len = 5 + (col_seed % 8).to_i
          head_y = ry + (((time * col_speed * 12.0).to_i64 + (col_seed % 40)).to_i % (rh + col_len)) - col_len

          (0...col_len).each do |drop_idx|
            cur_y = head_y - drop_idx
            next if cur_y < ry || cur_y >= ry + rh

            orig = source.get(x, cur_y)
            next if @preserve_text && orig.char != ' ' && orig.fg.type != Color::Type::None

            is_head = (drop_idx == 0)
            char_idx = (x + cur_y + (time * 5).to_i).abs % MATRIX_CHARS.size
            rain_char = MATRIX_CHARS[char_idx]

            rain_fg = if is_head
                        @lead_color
                      elsif drop_idx < 3
                        Color.bright_green
                      else
                        trail_factor = 1.0 - (drop_idx.to_f / col_len.to_f)
                        Color.lerp(Color.rgb(0, 40, 0), @trail_color, trail_factor)
                      end

            target.put_char(x, cur_y, rain_char, fg: rain_fg, bold: is_head)
          end
        end
      end
    end

    # Built-in retro CRT scanlines and phosphor glow shader pass
    class CrtPass < Pass
      property intensity : Float64
      property scanline_gap : Int32
      property phosphor_tint : Color
      property? flicker : Bool

      def initialize(
        region : Rect? = nil,
        @intensity : Float64 = 0.35,
        @scanline_gap : Int32 = 2,
        phosphor_tint : Color | Symbol | String = Color.none,
        @flicker : Bool = true,
      )
        super(region)
        @phosphor_tint = Color.from(phosphor_tint)
      end

      def apply(source : UI::Buffer, target : UI::Buffer, time : Float64, frame : UInt64) : Nil
        return unless @enabled

        rx = @region.try(&.x) || 0
        ry = @region.try(&.y) || 0
        rw = @region.try(&.width) || source.width
        rh = @region.try(&.height) || source.height

        rx = rx.clamp(0, source.width)
        ry = ry.clamp(0, source.height)
        rw = rw.clamp(0, source.width - rx)
        rh = rh.clamp(0, source.height - ry)

        flicker_mod = @flicker ? (Math.sin(time * 60.0) * 0.04) : 0.0

        (ry...(ry + rh)).each do |y|
          is_scanline = (y % @scanline_gap == 0)
          (rx...(rx + rw)).each do |x|
            cell = source.get(x, y)
            next if cell.char == ' ' && cell.bg.type == Color::Type::None

            new_fg = cell.fg
            if @phosphor_tint.type != Color::Type::None
              new_fg = Color.lerp(new_fg, @phosphor_tint, 0.25)
            end

            new_dim = cell.dim?
            if is_scanline
              dark_factor = (@intensity + flicker_mod).clamp(0.0, 0.9)
              new_fg = Color.lerp(new_fg, Color.black, dark_factor)
              new_dim = true
            end

            target.set(x, y, UI::Cell.new(
              char: cell.char,
              fg: new_fg,
              bg: cell.bg,
              bold: cell.bold? && !is_scanline,
              dim: new_dim,
              italic: cell.italic?,
              underline: cell.underline?,
              reverse: cell.reverse?
            ))
          end
        end
      end
    end

    # Built-in Cyberpunk Glitch & raster tearing shader pass
    class GlitchPass < Pass
      property intensity : Float64
      property slice_height : Int32
      property? chromatic_shift : Bool

      GLITCH_RUNES = ['!', '#', '$', '%', '&', '?', '░', '▒', '▓', '█', '<', '>', '/', '\\']

      def initialize(
        region : Rect? = nil,
        @intensity : Float64 = 0.2,
        @slice_height : Int32 = 3,
        @chromatic_shift : Bool = true,
      )
        super(region)
      end

      def apply(source : UI::Buffer, target : UI::Buffer, time : Float64, frame : UInt64) : Nil
        return unless @enabled

        rx = @region.try(&.x) || 0
        ry = @region.try(&.y) || 0
        rw = @region.try(&.width) || source.width
        rh = @region.try(&.height) || source.height

        rx = rx.clamp(0, source.width)
        ry = ry.clamp(0, source.height)
        rw = rw.clamp(0, source.width - rx)
        rh = rh.clamp(0, source.height - ry)

        # Trigger periodic glitch bursts
        glitch_phase = (time * 3.5) % 3.0
        is_glitching = (glitch_phase < 0.45)

        (ry...(ry + rh)).each do |y|
          t_int = (time * 10.0).to_i64 rescue 0_i64
          slice_seed = ((y // @slice_height).to_i64 &* 45678_i64) ^ t_int
          offset_x = 0

          if is_glitching && ((slice_seed.abs % 100).to_f / 100.0) < @intensity * 3.0
            offset_x = ((slice_seed.abs % 7) - 3).to_i
          end

          (rx...(rx + rw)).each do |x|
            src_x = (x + offset_x).clamp(rx, rx + rw - 1)
            cell = source.get(src_x, y)

            # Random character corruption
            t20 = (time * 20.0).to_i64 rescue 0_i64
            corrupt_seed = (x.to_i64 &* 12345_i64) ^ (y.to_i64 &* 67890_i64) ^ t20
            if is_glitching && ((corrupt_seed.abs % 1000).to_f / 1000.0) < (@intensity * 0.08) && cell.char != ' '
              rune_idx = corrupt_seed.abs.to_i % GLITCH_RUNES.size
              cell = UI::Cell.new(
                char: GLITCH_RUNES[rune_idx],
                fg: @chromatic_shift ? Color.bright_cyan : cell.fg,
                bg: cell.bg,
                bold: true
              )
            elsif is_glitching && @chromatic_shift && offset_x != 0 && cell.char != ' '
              cell = UI::Cell.new(
                char: cell.char,
                fg: offset_x > 0 ? Color.bright_red : Color.bright_cyan,
                bg: cell.bg,
                bold: cell.bold?
              )
            end

            target.set(x, y, cell)
          end
        end
      end
    end

    # Built-in 24-bit TrueColor Sine Wave Plasma shader pass
    class PlasmaPass < Pass
      property scale : Float64
      property speed : Float64
      property? shade_bg : Bool

      def initialize(
        region : Rect? = nil,
        @scale : Float64 = 0.2,
        @speed : Float64 = 1.5,
        @shade_bg : Bool = false,
      )
        super(region)
      end

      def apply(source : UI::Buffer, target : UI::Buffer, time : Float64, frame : UInt64) : Nil
        return unless @enabled

        rx = @region.try(&.x) || 0
        ry = @region.try(&.y) || 0
        rw = @region.try(&.width) || source.width
        rh = @region.try(&.height) || source.height

        rx = rx.clamp(0, source.width)
        ry = ry.clamp(0, source.height)
        rw = rw.clamp(0, source.width - rx)
        rh = rh.clamp(0, source.height - ry)

        t = time * @speed

        (ry...(ry + rh)).each do |y|
          (rx...(rx + rw)).each do |x|
            u = (x - rx).to_f * @scale
            v = (y - ry).to_f * @scale * 2.0 # Aspect ratio compensation

            v1 = Math.sin(u + t)
            v2 = Math.sin(v + t * 0.8)
            v3 = Math.sin((u + v) * 0.5 + t * 1.2)
            dist = Math.sqrt((u - 4.0)**2 + (v - 4.0)**2)
            v4 = Math.sin(dist + t)

            plasma_val = (v1 + v2 + v3 + v4) * 0.25 # -1.0 .. 1.0

            r = ((Math.sin(plasma_val * Math::PI) * 127.5) + 127.5).to_u8
            g = ((Math.sin(plasma_val * Math::PI + (2.0 * Math::PI / 3.0)) * 127.5) + 127.5).to_u8
            b = ((Math.sin(plasma_val * Math::PI + (4.0 * Math::PI / 3.0)) * 127.5) + 127.5).to_u8
            plasma_c = Color.rgb(r, g, b)

            cell = source.get(x, y)
            if @shade_bg
              target.set(x, y, UI::Cell.new(char: cell.char, fg: cell.fg, bg: plasma_c))
            else
              target.set(x, y, UI::Cell.new(char: cell.char == ' ' ? '█' : cell.char, fg: plasma_c, bg: cell.bg, bold: true))
            end
          end
        end
      end
    end

    # Built-in Ascending Fire dispersion shader pass
    class FirePass < Pass
      property speed : Float64

      FIRE_RAMP = [
        {' ', Color.none},
        {'.', Color.rgb(80, 0, 0)},
        {':', Color.rgb(180, 20, 0)},
        {'*', Color.rgb(240, 100, 0)},
        {'#', Color.rgb(255, 200, 0)},
        {'█', Color.rgb(255, 255, 220)},
      ]

      def initialize(region : Rect? = nil, @speed : Float64 = 1.0)
        super(region)
      end

      def apply(source : UI::Buffer, target : UI::Buffer, time : Float64, frame : UInt64) : Nil
        return unless @enabled

        rx = @region.try(&.x) || 0
        ry = @region.try(&.y) || 0
        rw = @region.try(&.width) || source.width
        rh = @region.try(&.height) || source.height

        rx = rx.clamp(0, source.width)
        ry = ry.clamp(0, source.height)
        rw = rw.clamp(0, source.width - rx)
        rh = rh.clamp(0, source.height - ry)

        (ry...(ry + rh)).each do |y|
          vert_ratio = (ry + rh - 1 - y).to_f / rh.to_f # 1.0 at bottom, 0.0 at top
          (rx...(rx + rw)).each do |x|
            t_fire = (time * @speed * 15.0).to_i64 rescue 0_i64
            seed = (x.to_i64 &* 4567_i64) ^ (y.to_i64 &* 8901_i64) ^ (t_fire &* 2345_i64)
            noise_val = ((seed.abs & 0xFF).to_f / 255.0)

            heat = (vert_ratio * 0.85) + (noise_val * 0.35)
            ramp_idx = (heat * (FIRE_RAMP.size - 1)).round.to_i.clamp(0, FIRE_RAMP.size - 1)
            char, fg = FIRE_RAMP[ramp_idx]

            cell = source.get(x, y)
            if cell.char != ' ' && cell.fg.type != Color::Type::None
              # Modulate text with fire glow
              target.set(x, y, UI::Cell.new(char: cell.char, fg: fg, bg: cell.bg, bold: true))
            else
              target.put_char(x, y, char, fg: fg, bold: ramp_idx >= 4)
            end
          end
        end
      end
    end

    # Built-in Radial Vignette spotlight shader pass
    class VignettePass < Pass
      property radius : Float64
      property falloff : Float64

      def initialize(region : Rect? = nil, @radius : Float64 = 0.8, @falloff : Float64 = 0.5)
        super(region)
      end

      def apply(source : UI::Buffer, target : UI::Buffer, time : Float64, frame : UInt64) : Nil
        return unless @enabled

        rx = @region.try(&.x) || 0
        ry = @region.try(&.y) || 0
        rw = @region.try(&.width) || source.width
        rh = @region.try(&.height) || source.height

        rx = rx.clamp(0, source.width)
        ry = ry.clamp(0, source.height)
        rw = rw.clamp(0, source.width - rx)
        rh = rh.clamp(0, source.height - ry)

        (ry...(ry + rh)).each do |y|
          v = (y - ry).to_f / rh.to_f
          (rx...(rx + rw)).each do |x|
            u = (x - rx).to_f / rw.to_f
            dist = Math.sqrt(((u - 0.5) * 2.0)**2 + ((v - 0.5) * 2.0)**2)

            cell = source.get(x, y)
            if dist > @radius
              darkness = ((dist - @radius) / @falloff).clamp(0.0, 1.0)
              shaded_fg = Color.lerp(cell.fg, Color.black, darkness)
              shaded_bg = Color.lerp(cell.bg, Color.black, darkness)
              target.set(x, y, UI::Cell.new(
                char: cell.char,
                fg: shaded_fg,
                bg: shaded_bg,
                bold: cell.bold?,
                dim: darkness > 0.4 || cell.dim?,
                italic: cell.italic?,
                underline: cell.underline?,
                reverse: cell.reverse?
              ))
            else
              target.set(x, y, cell)
            end
          end
        end
      end
    end
  end
end
