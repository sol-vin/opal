require "./pass"
require "./fast_math"
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
          v = (y - ry).to_f * @scale * 2.0 # Aspect ratio compensation
          v2 = FastMath.sin(v + t * 0.8)

          (rx...(rx + rw)).each do |x|
            u = (x - rx).to_f * @scale

            v1 = FastMath.sin(u + t)
            v3 = FastMath.sin((u + v) * 0.5 + t * 1.2)
            dist = Math.sqrt((u - 4.0)**2 + (v - 4.0)**2)
            v4 = FastMath.sin(dist + t)

            plasma_val = (v1 + v2 + v3 + v4) * 0.25 # -1.0 .. 1.0

            r = ((FastMath.sin(plasma_val * Math::PI) * 127.5) + 127.5).to_u8
            g = ((FastMath.sin(plasma_val * Math::PI + (2.0 * Math::PI / 3.0)) * 127.5) + 127.5).to_u8
            b = ((FastMath.sin(plasma_val * Math::PI + (4.0 * Math::PI / 3.0)) * 127.5) + 127.5).to_u8
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

    # Built-in Hyperdrive 3D Warp Starfield shader pass
    class StarfieldPass < Pass
      property speed : Float64
      property count : Int32
      property? preserve_text : Bool

      def initialize(
        region : Rect? = nil,
        @speed : Float64 = 1.0,
        @count : Int32 = 80,
        @preserve_text : Bool = true,
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
        return if rw <= 0 || rh <= 0

        cx = rx + rw // 2
        cy = ry + rh // 2

        (0...@count).each do |i|
          # Deterministic pseudo-random seed per star
          seed = (i.to_i64 &* 2654435761_i64) ^ 0x9e3779b9_i64
          orig_x = (((seed &* 1103515245_i64 + 12345).abs % 2000).to_f - 1000.0) / 1000.0
          orig_y = ((((seed >> 16) &* 1103515245_i64 + 12345).abs % 2000).to_f - 1000.0) / 1000.0

          # Distance Z moves from 1.0 to 0.02
          t_offset = (i.to_f / @count.to_f)
          z = ((1.0 - ((time * @speed * 0.4 + t_offset) % 1.0))).clamp(0.02, 1.0)

          # Perspective projection (terminal 2:1 character aspect ratio compensated)
          px = cx + (orig_x / z * (rw.to_f * 0.48)).round.to_i
          py = cy + (orig_y / z * (rh.to_f * 0.28)).round.to_i

          next if px < rx || px >= rx + rw || py < ry || py >= ry + rh

          orig = source.get(px, py)
          next if @preserve_text && orig.char != ' ' && orig.fg.type != Color::Type::None

          dist = 1.0 - z # 0.0 at center, 1.0 at screen edge
          char, fg, bold = if dist > 0.8
                             {'#', Color.bright_white, true}
                           elsif dist > 0.55
                             {'*', Color.bright_cyan, true}
                           elsif dist > 0.3
                             {'+', Color.cyan, false}
                           elsif dist > 0.15
                             {'.', Color.rgb(80, 140, 220), false}
                           else
                             {'.', Color.rgb(40, 60, 120), false}
                           end

          target.put_char(px, py, char, fg: fg, bold: bold)
        end
      end
    end

    # Built-in Water Ripple & Caustic Distortion shader pass
    class RipplePass < Pass
      property speed : Float64
      property frequency : Float64
      property amplitude : Float64

      def initialize(
        region : Rect? = nil,
        @speed : Float64 = 2.0,
        @frequency : Float64 = 0.4,
        @amplitude : Float64 = 1.5,
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
        return if rw <= 0 || rh <= 0

        cx = rx + rw / 2.0 + Math.sin(time * 0.8) * (rw / 6.0)
        cy = ry + rh / 2.0 + Math.cos(time * 0.7) * (rh / 6.0)

        (ry...(ry + rh)).each do |y|
          dy = (y - cy).to_f * 2.0 # Aspect ratio compensation
          (rx...(rx + rw)).each do |x|
            dx = (x - cx).to_f
            dist = Math.sqrt(dx * dx + dy * dy)
            wave = Math.sin(dist * @frequency - time * @speed)

            # Refractive displacement
            offset_x = (wave * @amplitude).round.to_i
            src_x = (x + offset_x).clamp(rx, rx + rw - 1)
            cell = source.get(src_x, y)

            # Caustic aqua/cyan tinting
            caustic_val = ((wave + 1.0) * 0.5) # 0.0 .. 1.0
            g = (100.0 + caustic_val * 155.0).to_u8
            b = (180.0 + caustic_val * 75.0).to_u8
            caustic_color = Color.rgb(0_u8, g, b)

            if cell.char != ' ' && cell.fg.type != Color::Type::None
              tinted_fg = Color.lerp(cell.fg, caustic_color, 0.4)
              target.set(x, y, UI::Cell.new(char: cell.char, fg: tinted_fg, bg: cell.bg, bold: wave > 0.4))
            else
              wave_char = if wave > 0.7
                            '~'
                          elsif wave > 0.3
                            '-'
                          elsif wave > -0.2
                            '.'
                          else
                            ' '
                          end
              target.put_char(x, y, wave_char, fg: caustic_color, dim: wave <= 0.3)
            end
          end
        end
      end
    end

    # Built-in 3D Demoscene Infinite Cyber Tunnel shader pass
    class TunnelPass < Pass
      property speed : Float64
      property rotation_speed : Float64

      def initialize(
        region : Rect? = nil,
        @speed : Float64 = 1.2,
        @rotation_speed : Float64 = 0.5,
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
        return if rw <= 0 || rh <= 0

        cx = rx + rw / 2.0
        cy = ry + rh / 2.0

        (ry...(ry + rh)).each do |y|
          dy = (y - cy).to_f / (rh / 2.0) * 1.8 # 2:1 character aspect ratio
          (rx...(rx + rw)).each do |x|
            dx = (x - cx).to_f / (rw / 2.0)
            r = Math.sqrt(dx * dx + dy * dy)
            next if r < 0.05

            theta = Math.atan2(dy, dx) # -PI .. PI

            u = ((theta / Math::PI * 0.5 + 0.5) * 8.0 + time * @rotation_speed) % 1.0
            v = (1.0 / r + time * @speed) % 1.0

            # Checker / ring depth pattern
            check_u = (u * 8.0).to_i % 2
            check_v = (v * 8.0).to_i % 2
            is_stripe = (check_u ^ check_v) == 1

            # Depth falloff and neon purple/cyan palette
            depth = (1.0 - (1.0 / (r * 1.5 + 1.0))).clamp(0.0, 1.0)
            neon_r = ((Math.sin(v * Math::PI * 2.0) * 100.0) + 155.0).to_u8
            neon_g = ((Math.cos(u * Math::PI * 2.0) * 80.0) + 90.0).to_u8
            neon_b = 240_u8
            tunnel_color = Color.rgb(neon_r, neon_g, neon_b)
            shaded_color = Color.lerp(Color.black, tunnel_color, depth)

            cell = source.get(x, y)
            if cell.char != ' ' && cell.fg.type != Color::Type::None
              target.set(x, y, UI::Cell.new(char: cell.char, fg: shaded_color, bg: cell.bg, bold: true))
            else
              char = is_stripe ? '▓' : '░'
              target.put_char(x, y, char, fg: shaded_color, dim: depth < 0.4)
            end
          end
        end
      end
    end

    # Procedural 3D Raymarched Sphere shader pass with dynamic orbital lighting,
    # diffuse Lambertian shading, specular highlights, and ASCII luminance ramping.
    class RaymarchSpherePass < Pass
      property speed : Float64
      property radius : Float64
      property sphere_color : Color
      property light_color : Color
      property? preserve_text : Bool

      RAMP = [' ', '.', ':', '-', '=', '+', '*', '%', '#', '@', '$']

      def initialize(
        region : Rect? = nil,
        @speed : Float64 = 1.0,
        @radius : Float64 = 0.75,
        sphere_color : Color | Symbol | String = :bright_cyan,
        light_color : Color | Symbol | String = :white,
        @preserve_text : Bool = false,
      )
        super(region)
        @sphere_color = Color.from(sphere_color)
        @light_color = Color.from(light_color)
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
        return if rw <= 0 || rh <= 0

        cx = rx + rw / 2.0
        cy = ry + rh / 2.0
        half_w = rw / 2.0
        half_h = rh / 2.0

        t = time * @speed
        # Light position in 3D orbiting the sphere
        lx = FastMath.cos(t)
        ly = FastMath.sin(t * 0.7) * 0.6
        lz = FastMath.sin(t)
        l_len = Math.sqrt(lx * lx + ly * ly + lz * lz)
        lx /= l_len; ly /= l_len; lz /= l_len

        r_sq = @radius * @radius

        (ry...(ry + rh)).each do |y|
          ny = (y - cy).to_f / half_h * 1.8 # Aspect compensation
          ny_sq = ny * ny

          (rx...(rx + rw)).each do |x|
            nx = (x - cx).to_f / half_w
            d_sq = nx * nx + ny_sq

            orig = source.get(x, y)
            if d_sq <= r_sq
              nz = Math.sqrt(r_sq - d_sq)
              norm_x = nx / @radius
              norm_y = ny / @radius
              norm_z = nz / @radius

              diff = Math.max(0.0, norm_x * lx + norm_y * ly + norm_z * lz)

              hx = lx; hy = ly; hz = lz + 1.0
              h_len = Math.sqrt(hx * hx + hy * hy + hz * hz)
              if h_len > 0.0001
                hx /= h_len; hy /= h_len; hz /= h_len
              end
              ndoth = Math.max(0.0, norm_x * hx + norm_y * hy + norm_z * hz)
              spec = (ndoth ** 16) * 0.8

              intensity = (0.15 + diff * 0.75 + spec).clamp(0.0, 1.0)
              shaded_c = Color.lerp(Color.black, @sphere_color, intensity)
              if spec > 0.3
                shaded_c = Color.lerp(shaded_c, @light_color, ((spec - 0.3) / 0.7).clamp(0.0, 1.0))
              end

              ramp_idx = ((intensity * (RAMP.size - 1)).round.to_i).clamp(0, RAMP.size - 1)
              char = if @preserve_text && orig.char != ' '
                       orig.char
                     else
                       RAMP[ramp_idx]
                     end

              target.set(x, y, UI::Cell.new(
                char: char,
                fg: shaded_c,
                bg: orig.bg,
                bold: intensity > 0.6
              ))
            elsif !@preserve_text || orig.char == ' '
              target.set(x, y, orig)
            end
          end
        end
      end
    end

    # Procedural Voronoi (Worley Cellular Noise) shader pass
    # Renders organic crystal-like cells, glowing neon boundaries, and pulsating nuclei.
    class VoronoiPass < Pass
      property speed : Float64
      property scale : Float64
      property border_color : Color
      property inner_color : Color

      def initialize(
        region : Rect? = nil,
        @speed : Float64 = 0.8,
        @scale : Float64 = 0.15,
        border_color : Color | Symbol | String = :bright_cyan,
        inner_color : Color | Symbol | String = :blue,
      )
        super(region)
        @border_color = Color.from(border_color)
        @inner_color = Color.from(inner_color)
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
        return if rw <= 0 || rh <= 0

        t = time * @speed

        (ry...(ry + rh)).each do |y|
          gy = (y - ry).to_f * @scale * 2.0
          iy = gy.floor.to_i

          (rx...(rx + rw)).each do |x|
            gx = (x - rx).to_f * @scale
            ix = gx.floor.to_i

            min_d1 = 999.0
            min_d2 = 999.0

            (-1..1).each do |dy|
              ny = iy + dy
              (-1..1).each do |dx|
                nx = ix + dx

                hash = ((nx.to_i64 &* 374761393_i64) ^ (ny.to_i64 &* 668265263_i64))
                phase_x = ((hash % 1000).to_f / 1000.0) * Math::PI * 2.0
                phase_y = (((hash >> 10) % 1000).to_f / 1000.0) * Math::PI * 2.0

                px = nx.to_f + 0.5 + FastMath.sin(t + phase_x) * 0.4
                py = ny.to_f + 0.5 + FastMath.cos(t * 1.3 + phase_y) * 0.4

                dist = Math.sqrt((gx - px)**2 + (gy - py)**2)

                if dist < min_d1
                  min_d2 = min_d1
                  min_d1 = dist
                elsif dist < min_d2
                  min_d2 = dist
                end
              end
            end

            edge_dist = min_d2 - min_d1
            is_edge = edge_dist < 0.18
            cell = source.get(x, y)

            if is_edge
              edge_factor = (1.0 - (edge_dist / 0.18)).clamp(0.0, 1.0)
              c = Color.lerp(@inner_color, @border_color, edge_factor)
              char = edge_factor > 0.6 ? '▓' : '▒'
              if cell.char != ' ' && cell.fg.type != Color::Type::None
                target.set(x, y, UI::Cell.new(char: cell.char, fg: @border_color, bg: cell.bg, bold: true))
              else
                target.put_char(x, y, char, fg: c, bold: true)
              end
            else
              intensity = (1.0 - (min_d1 * 0.8)).clamp(0.0, 1.0)
              c = Color.lerp(Color.black, @inner_color, intensity)
              if cell.char != ' ' && cell.fg.type != Color::Type::None
                target.set(x, y, UI::Cell.new(char: cell.char, fg: Color.lerp(cell.fg, c, 0.4), bg: cell.bg))
              else
                char = intensity > 0.7 ? '.' : ' '
                target.put_char(x, y, char, fg: c, dim: true)
              end
            end
          end
        end
      end
    end

    # Procedural multi-layer parallax mountain/ridge landscape with starry sky
    class FractalLandscapePass < Pass
      property speed : Float64
      property sky_color : Color
      property mountain_color : Color
      property ridge_color : Color
      property foreground_color : Color

      def initialize(
        region : Rect? = nil,
        @speed : Float64 = 1.0,
        sky_color : Color | Symbol | String = :dark_gray,
        mountain_color : Color | Symbol | String = :blue,
        ridge_color : Color | Symbol | String = :magenta,
        foreground_color : Color | Symbol | String = :bright_cyan,
      )
        super(region)
        @sky_color = Color.from(sky_color)
        @mountain_color = Color.from(mountain_color)
        @ridge_color = Color.from(ridge_color)
        @foreground_color = Color.from(foreground_color)
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
        return if rw <= 0 || rh <= 0

        t = time * @speed

        (rx...(rx + rw)).each do |x|
          norm_x = (x - rx).to_f

          # Layer 1: Distant mountains (slow scroll)
          m_x = norm_x * 0.05 + t * 0.2
          h_mountain = (rh * 0.45) + (FastMath.sin(m_x) * 0.6 + FastMath.sin(m_x * 2.3 + 1.2) * 0.3 + FastMath.sin(m_x * 5.1) * 0.1) * (rh * 0.25)

          # Layer 2: Midground ridge (medium scroll)
          r_x = norm_x * 0.08 + t * 0.6
          h_ridge = (rh * 0.65) + (FastMath.sin(r_x) * 0.5 + FastMath.sin(r_x * 2.7 + 0.8) * 0.35 + FastMath.sin(r_x * 6.0) * 0.15) * (rh * 0.2)

          # Layer 3: Foreground hills (fast scroll)
          f_x = norm_x * 0.12 + t * 1.4
          h_fore = (rh * 0.82) + (FastMath.sin(f_x) * 0.4 + FastMath.sin(f_x * 3.1 + 2.0) * 0.4) * (rh * 0.12)

          (ry...(ry + rh)).each do |y|
            rel_y = (y - ry).to_f
            cell = source.get(x, y)

            if rel_y >= h_fore
              depth = ((rel_y - h_fore) / (rh - h_fore + 0.001)).clamp(0.0, 1.0)
              c = Color.lerp(@foreground_color, Color.black, depth * 0.3)
              if cell.char != ' ' && cell.fg.type != Color::Type::None
                target.set(x, y, UI::Cell.new(char: cell.char, fg: c, bg: cell.bg, bold: true))
              else
                target.put_char(x, y, rel_y.to_i == h_fore.to_i ? '/' : '█', fg: c, bold: true)
              end
            elsif rel_y >= h_ridge
              c = @ridge_color
              if cell.char != ' ' && cell.fg.type != Color::Type::None
                target.set(x, y, UI::Cell.new(char: cell.char, fg: c, bg: cell.bg))
              else
                target.put_char(x, y, rel_y.to_i == h_ridge.to_i ? '^' : '▓', fg: c)
              end
            elsif rel_y >= h_mountain
              c = @mountain_color
              if cell.char != ' ' && cell.fg.type != Color::Type::None
                target.set(x, y, UI::Cell.new(char: cell.char, fg: c, bg: cell.bg, dim: true))
              else
                target.put_char(x, y, rel_y.to_i == h_mountain.to_i ? '▲' : '░', fg: c, dim: true)
              end
            else
              if cell.char != ' ' && cell.fg.type != Color::Type::None
                target.set(x, y, cell)
              else
                star_seed = (x.to_i64 &* 54321_i64) ^ (y.to_i64 &* 98765_i64)
                is_star = (star_seed.abs % 73) == 0
                if is_star
                  star_twinkle = (FastMath.sin(t * 3.0 + (star_seed % 10)) > 0.0)
                  target.put_char(x, y, star_twinkle ? '*' : '.', fg: @sky_color, dim: !star_twinkle)
                else
                  target.put_char(x, y, ' ', fg: Color.none)
                end
              end
            end
          end
        end
      end
    end

    # Procedural multi-band equalizer / audio spectrum visualizer
    # Features dynamic frequency bands, responsive VU meter gradients, and peak hold markers.
    class AudioVisualizerPass < Pass
      property speed : Float64
      property bar_count : Int32
      property low_color : Color
      property mid_color : Color
      property high_color : Color
      property peak_color : Color

      def initialize(
        region : Rect? = nil,
        @speed : Float64 = 1.0,
        @bar_count : Int32 = 16,
        low_color : Color | Symbol | String = :green,
        mid_color : Color | Symbol | String = :yellow,
        high_color : Color | Symbol | String = :bright_red,
        peak_color : Color | Symbol | String = :bright_white,
      )
        super(region)
        @low_color = Color.from(low_color)
        @mid_color = Color.from(mid_color)
        @high_color = Color.from(high_color)
        @peak_color = Color.from(peak_color)
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
        return if rw <= 0 || rh <= 0

        t = time * @speed
        bars = Math.min(@bar_count, rw // 2)
        return if bars <= 0

        bar_width = Math.max(1, rw // bars)
        effective_width = bars * bar_width
        start_x = rx + (rw - effective_width) // 2

        (0...bars).each do |b|
          freq = (b + 1).to_f / bars.to_f
          bass_hit = (FastMath.sin(t * 4.0) ** 4) * (1.0 - freq)
          rhythm = FastMath.sin(t * (3.0 + freq * 8.0) + freq * 12.0).abs
          noise = (FastMath.sin(t * 15.0 + b * 2.3) * 0.2).abs
          val = ((bass_hit * 0.7 + rhythm * 0.5 + noise * 0.3) * 1.1).clamp(0.05, 1.0)

          bar_height = (val * (rh - 2)).round.to_i
          peak_height = ((val + 0.1).clamp(0.0, 1.0) * (rh - 2)).round.to_i

          bx = start_x + b * bar_width

          (0...bar_width).each do |bw_offset|
            col_x = bx + bw_offset
            next if col_x >= rx + rw

            (0...rh).each do |level|
              target_y = ry + rh - 1 - level
              next if target_y < ry || target_y >= ry + rh

              cell = source.get(col_x, target_y)

              if level < bar_height
                frac = level.to_f / rh.to_f
                color = if frac < 0.5
                          Color.lerp(@low_color, @mid_color, frac * 2.0)
                        else
                          Color.lerp(@mid_color, @high_color, (frac - 0.5) * 2.0)
                        end
                if cell.char != ' ' && cell.fg.type != Color::Type::None
                  target.set(col_x, target_y, UI::Cell.new(char: cell.char, fg: color, bg: cell.bg, bold: frac > 0.6))
                else
                  target.put_char(col_x, target_y, '█', fg: color, bold: frac > 0.6)
                end
              elsif level == peak_height
                target.put_char(col_x, target_y, '▔', fg: @peak_color, bold: true)
              end
            end
          end
        end
      end
    end
  end
end
