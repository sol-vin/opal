require "../element"
require "../buffer"
require "../../image/pixel_buffer"
require "../../style/color"

module Opal
  module UI
    # ASCII rendering mode for image conversion
    enum AsciiRenderMode
      # High-density 2-pixel-per-cell mode using Unicode upper half block '▀'
      # Top pixel sets foreground color, bottom pixel sets background color.
      HalfBlock

      # Optical character density matching using ASCII glyphs based on pixel luminance
      NearestChar

      def self.from(val : Symbol | AsciiRenderMode) : AsciiRenderMode
        case val
        when AsciiRenderMode                        then val
        when :half_block, :halfblock, :block        then HalfBlock
        when :nearest_char, :nearest, :ascii, :char then NearestChar
        else                                             HalfBlock
        end
      end
    end

    # UI Element that renders TrueColor pixel buffers as terminal ASCII art.
    # Supports high-resolution half-block rendering, optical luminance nearest-char
    # rendering, nearest-neighbor & bilinear interpolation, and aspect ratio compensation.
    class AsciiImage < Element
      property image : Opal::Image::PixelBuffer
      property mode : AsciiRenderMode
      property interpolation : Opal::Image::Interpolation
      property ramp : String
      property? colorize : Bool
      property? bold : Bool
      property bg : Color

      # Standard 10-level ASCII optical density ramp (light to dark)
      RAMP_STANDARD = " .:-=+*#%@"

      # Detailed 70-level ASCII optical density ramp
      RAMP_DETAILED = " .'`^\",:;Il!i><~+_-?][}{1)(|\\/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$"

      # High-contrast glyph ramp
      RAMP_BLOCKS = " ░▒▓█"

      def initialize(
        @image : Opal::Image::PixelBuffer,
        mode : Symbol | AsciiRenderMode = :half_block,
        interpolation : Symbol | Opal::Image::Interpolation = :bilinear,
        @ramp : String = RAMP_STANDARD,
        @colorize : Bool = true,
        @bold : Bool = false,
        bg : Color | Symbol | String = Color.none,
      )
        @mode = AsciiRenderMode.from(mode)
        @interpolation = Opal::Image::Interpolation.from(interpolation)
        @bg = Color.from(bg)
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        img_w = @image.width
        img_h = @image.height

        case @mode
        when AsciiRenderMode::HalfBlock
          # 1 cell = 1 horizontal pixel x 2 vertical pixels
          cell_h = (img_h / 2.0).ceil.to_i
          {Math.min(img_w, available_w), Math.min(cell_h, available_h)}
        else
          # 1 cell = 1 character (terminal 2:1 cell aspect compensation)
          cell_h = (img_h / 2.0).ceil.to_i
          {Math.min(img_w, available_w), Math.min(cell_h, available_h)}
        end
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0

        case @mode
        when AsciiRenderMode::HalfBlock
          render_half_block(buffer, x, y, width, height)
        when AsciiRenderMode::NearestChar
          render_nearest_char(buffer, x, y, width, height)
        end
      end

      private def render_half_block(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        # In half-block mode, each cell holds 2 vertical pixels (top & bottom)
        target_pw = width
        target_ph = height * 2

        scaled = @image.resize(target_pw, target_ph, @interpolation)

        (0...height).each do |cell_y|
          dst_y = y + cell_y
          break if dst_y >= buffer.height

          top_py = cell_y * 2
          bot_py = top_py + 1

          (0...width).each do |cell_x|
            dst_x = x + cell_x
            break if dst_x >= buffer.width

            c_top = scaled.get(cell_x, top_py)
            c_bot = (bot_py < target_ph) ? scaled.get(cell_x, bot_py) : @bg

            if @colorize
              buffer.put_char(dst_x, dst_y, '▀', fg: c_top, bg: c_bot)
            else
              # Monochrome grayscale
              l_top = (0.299 * c_top.r + 0.587 * c_top.g + 0.114 * c_top.b).round.to_u8
              l_bot = (0.299 * c_bot.r + 0.587 * c_bot.g + 0.114 * c_bot.b).round.to_u8
              buffer.put_char(dst_x, dst_y, '▀', fg: Color.rgb(l_top, l_top, l_top), bg: Color.rgb(l_bot, l_bot, l_bot))
            end
          end
        end
      end

      private def render_nearest_char(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        # In nearest-char mode, scale image to match width & height
        scaled = @image.resize(width, height, @interpolation)
        ramp_chars = @ramp.chars
        ramp_len = ramp_chars.size

        (0...height).each do |cell_y|
          dst_y = y + cell_y
          break if dst_y >= buffer.height

          (0...width).each do |cell_x|
            dst_x = x + cell_x
            break if dst_x >= buffer.width

            pixel = scaled.get(cell_x, cell_y)

            # Perceived luminance: Rec. 601 coefficients
            lum = (0.299 * pixel.r.to_f + 0.587 * pixel.g.to_f + 0.114 * pixel.b.to_f) / 255.0
            ramp_idx = (lum * (ramp_len - 1)).round.to_i.clamp(0, ramp_len - 1)
            glyph = ramp_chars[ramp_idx]

            fg_color = @colorize ? pixel : Color.white
            buffer.put_char(
              dst_x,
              dst_y,
              glyph,
              fg: fg_color,
              bg: @bg,
              bold: @bold || (lum > 0.65)
            )
          end
        end
      end
    end
  end
end
