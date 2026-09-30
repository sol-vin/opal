require "../style/color"

module Opal
  module Image
    # Interpolation algorithm used when scaling pixel buffers.
    enum Interpolation
      Nearest
      Bilinear

      def self.from(val : Symbol | Interpolation) : Interpolation
        case val
        when Interpolation               then val
        when :nearest, :nearest_neighbor then Nearest
        when :bilinear                   then Bilinear
        else                                  Bilinear
        end
      end
    end

    # 2D TrueColor pixel buffer supporting direct coordinate access, algorithmic
    # generators, high-fidelity nearest & bilinear interpolation, and file decoders.
    class PixelBuffer
      getter width : Int32
      getter height : Int32
      getter pixels : Array(Color)

      def initialize(@width : Int32, @height : Int32, default_color : Color = Color.none)
        raise ArgumentError.new("Width and height must be positive") if @width <= 0 || @height <= 0
        @pixels = Array(Color).new(@width * @height, default_color)
      end

      def initialize(@width : Int32, @height : Int32, @pixels : Array(Color))
        expected_size = @width * @height
        if @pixels.size != expected_size
          raise ArgumentError.new("Pixels array size (#{@pixels.size}) does not match dimensions (#{expected_size})")
        end
      end

      def in_bounds?(x : Int32, y : Int32) : Bool
        x >= 0 && x < @width && y >= 0 && y < @height
      end

      def get(x : Int32, y : Int32) : Color
        return Color.none unless in_bounds?(x, y)
        @pixels[y * @width + x]
      end

      def set(x : Int32, y : Int32, color : Color) : Nil
        return unless in_bounds?(x, y)
        @pixels[y * @width + x] = color
      end

      def clone : PixelBuffer
        PixelBuffer.new(@width, @height, @pixels.dup)
      end

      # Resizes the pixel buffer to the target dimensions using either
      # nearest-neighbor or bilinear filtering.
      def resize(target_w : Int32, target_h : Int32, interpolation : Interpolation = Interpolation::Bilinear) : PixelBuffer
        return clone if target_w == @width && target_h == @height
        raise ArgumentError.new("Target dimensions must be positive") if target_w <= 0 || target_h <= 0

        target = PixelBuffer.new(target_w, target_h)

        scale_x = @width.to_f / target_w.to_f
        scale_y = @height.to_f / target_h.to_f

        case interpolation
        when Interpolation::Nearest
          (0...target_h).each do |ty|
            sy = (ty.to_f * scale_y).to_i.clamp(0, @height - 1)
            row_offset = sy * @width
            target_row_offset = ty * target_w

            (0...target_w).each do |tx|
              sx = (tx.to_f * scale_x).to_i.clamp(0, @width - 1)
              target.pixels[target_row_offset + tx] = @pixels[row_offset + sx]
            end
          end
        when Interpolation::Bilinear
          (0...target_h).each do |ty|
            # Map target pixel center to continuous source coordinates
            gy = (ty.to_f + 0.5) * scale_y - 0.5
            y0 = gy.floor.to_i.clamp(0, @height - 1)
            y1 = (y0 + 1).clamp(0, @height - 1)
            dy = (gy - gy.floor).clamp(0.0, 1.0)

            row0 = y0 * @width
            row1 = y1 * @width
            target_row = ty * target_w

            (0...target_w).each do |tx|
              gx = (tx.to_f + 0.5) * scale_x - 0.5
              x0 = gx.floor.to_i.clamp(0, @width - 1)
              x1 = (x0 + 1).clamp(0, @width - 1)
              dx = (gx - gx.floor).clamp(0.0, 1.0)

              c00 = @pixels[row0 + x0]
              c10 = @pixels[row0 + x1]
              c01 = @pixels[row1 + x0]
              c11 = @pixels[row1 + x1]

              # Bilinear interpolation across RGB channels
              r_top = c00.r.to_f * (1.0 - dx) + c10.r.to_f * dx
              r_bot = c01.r.to_f * (1.0 - dx) + c11.r.to_f * dx
              r = (r_top * (1.0 - dy) + r_bot * dy).round.to_u8

              g_top = c00.g.to_f * (1.0 - dx) + c10.g.to_f * dx
              g_bot = c01.g.to_f * (1.0 - dx) + c11.g.to_f * dx
              g = (g_top * (1.0 - dy) + g_bot * dy).round.to_u8

              b_top = c00.b.to_f * (1.0 - dx) + c10.b.to_f * dx
              b_bot = c01.b.to_f * (1.0 - dx) + c11.b.to_f * dx
              b = (b_top * (1.0 - dy) + b_bot * dy).round.to_u8

              target.pixels[target_row + tx] = Color.rgb(r, g, b)
            end
          end
        end

        target
      end

      # =======================================================================
      # Built-in Sample Procedural Image Generators
      # =======================================================================

      # Generates a radiant 24-bit TrueColor Opal gemstone with multi-faceted refraction
      def self.sample_gem(w : Int32 = 48, h : Int32 = 48) : PixelBuffer
        buf = new(w, h, Color.rgb(8, 12, 22))
        cx = w / 2.0
        cy = h / 2.0
        radius = Math.min(cx, cy) * 0.88

        (0...h).each do |y|
          dy = (y - cy).to_f
          (0...w).each do |x|
            dx = (x - cx).to_f
            dist = Math.sqrt(dx * dx + dy * dy)

            if dist <= radius
              # Facet angle & radial depth
              angle = Math.atan2(dy, dx)
              facet = ((angle / Math::PI * 4.0 + 4.0).to_i % 8).to_f / 8.0
              norm_d = dist / radius

              # Iridescent opal rainbow dispersion
              hue_shift = facet * 0.4 + norm_d * 0.3
              r = ((Math.sin((hue_shift + 0.0) * Math::PI * 2.0) * 110.0) + 145.0).to_u8
              g = ((Math.sin((hue_shift + 0.33) * Math::PI * 2.0) * 110.0) + 145.0).to_u8
              b = ((Math.sin((hue_shift + 0.67) * Math::PI * 2.0) * 90.0) + 165.0).to_u8

              # Specular highlight on top-left
              spec_dx = x - (cx - radius * 0.35)
              spec_dy = y - (cy - radius * 0.35)
              spec_dist = Math.sqrt(spec_dx * spec_dx + spec_dy * spec_dy)
              if spec_dist < radius * 0.35
                spec_factor = 1.0 - (spec_dist / (radius * 0.35))
                r = (r.to_f + (255.0 - r.to_f) * spec_factor).to_u8
                g = (g.to_f + (255.0 - g.to_f) * spec_factor).to_u8
                b = (b.to_f + (255.0 - b.to_f) * spec_factor).to_u8
              end

              # Subtle edge darkening
              if norm_d > 0.82
                edge_factor = 1.0 - ((norm_d - 0.82) / 0.18) * 0.4
                r = (r.to_f * edge_factor).to_u8
                g = (g.to_f * edge_factor).to_u8
                b = (b.to_f * edge_factor).to_u8
              end

              buf.set(x, y, Color.rgb(r, g, b))
            end
          end
        end
        buf
      end

      # Generates a retro twilight mountain landscape with sunset gradient and sun
      def self.sample_landscape(w : Int32 = 48, h : Int32 = 36) : PixelBuffer
        buf = new(w, h)
        sun_cx = w * 0.68
        sun_cy = h * 0.38
        sun_rad = h * 0.22

        (0...h).each do |y|
          y_ratio = y.to_f / h.to_f

          # Sunset gradient background (Violet -> Magenta -> Deep Orange -> Amber)
          sky_r = (80.0 + y_ratio * 170.0).clamp(0.0, 255.0).to_u8
          sky_g = (20.0 + y_ratio * 120.0).clamp(0.0, 255.0).to_u8
          sky_b = (120.0 - y_ratio * 90.0).clamp(0.0, 255.0).to_u8

          (0...w).each do |x|
            # Sun disk
            dx = x - sun_cx
            dy = y - sun_cy
            dist = Math.sqrt(dx * dx + dy * dy)

            color = if dist <= sun_rad
                      glow = 1.0 - (dist / sun_rad)
                      Color.rgb(255_u8, (200.0 + glow * 55.0).to_u8, (80.0 + glow * 100.0).to_u8)
                    else
                      Color.rgb(sky_r, sky_g, sky_b)
                    end

            # Mountain ridge 1 (Back)
            ridge1_y = (h * 0.60) + Math.sin(x.to_f * 0.2) * 3.0 + Math.cos(x.to_f * 0.08) * 4.0
            if y >= ridge1_y
              color = Color.rgb(65_u8, 30_u8, 85_u8)
            end

            # Mountain ridge 2 (Foreground)
            ridge2_y = (h * 0.76) + Math.cos(x.to_f * 0.25) * 4.0 + Math.sin(x.to_f * 0.12) * 5.0
            if y >= ridge2_y
              color = Color.rgb(22_u8, 12_u8, 42_u8)
            end

            buf.set(x, y, color)
          end
        end
        buf
      end

      # =======================================================================
      # Standard Image Parsers (PPM & Uncompressed BMP)
      # =======================================================================

      # Parses Netpbm PPM (P3 ASCII or P6 Binary) image stream
      def self.from_ppm(content : String) : PixelBuffer
        tokens = content.split(/\s+/).reject(&.empty?)
        idx = 0

        # Skip comments
        while idx < tokens.size && tokens[idx].starts_with?('#')
          idx += 1
        end

        magic = tokens[idx]
        idx += 1

        width = tokens[idx].to_i
        idx += 1
        height = tokens[idx].to_i
        idx += 1
        max_val = tokens[idx].to_f
        idx += 1

        buf = new(width, height)

        (0...height).each do |y|
          (0...width).each do |x|
            break if idx + 2 >= tokens.size
            r = ((tokens[idx].to_i.to_f / max_val) * 255.0).clamp(0.0, 255.0).to_u8
            g = ((tokens[idx + 1].to_i.to_f / max_val) * 255.0).clamp(0.0, 255.0).to_u8
            b = ((tokens[idx + 2].to_i.to_f / max_val) * 255.0).clamp(0.0, 255.0).to_u8
            idx += 3
            buf.set(x, y, Color.rgb(r, g, b))
          end
        end

        buf
      end

      # Parses 24-bit or 32-bit uncompressed Windows BMP bytes
      def self.from_bmp(bytes : Bytes) : PixelBuffer
        raise ArgumentError.new("BMP data too small") if bytes.size < 54
        raise ArgumentError.new("Invalid BMP signature") unless bytes[0] == 0x42 && bytes[1] == 0x4D # 'BM'

        data_offset = bytes[10].to_i | (bytes[11].to_i << 8) | (bytes[12].to_i << 16) | (bytes[13].to_i << 24)
        width = bytes[18].to_i | (bytes[19].to_i << 8) | (bytes[20].to_i << 16) | (bytes[21].to_i << 24)
        height = bytes[22].to_i | (bytes[23].to_i << 8) | (bytes[24].to_i << 16) | (bytes[25].to_i << 24)
        bpp = bytes[28].to_i | (bytes[29].to_i << 8)

        raise ArgumentError.new("Unsupported BMP depth #{bpp} bpp (expected 24 or 32)") unless bpp == 24 || bpp == 32

        is_bottom_up = height > 0
        height = height.abs

        buf = new(width, height)
        bytes_per_pixel = bpp // 8
        row_stride = ((width * bytes_per_pixel + 3) // 4) * 4

        (0...height).each do |row|
          y = is_bottom_up ? (height - 1 - row) : row
          row_start = data_offset + row * row_stride

          (0...width).each do |x|
            pixel_start = row_start + x * bytes_per_pixel
            break if pixel_start + 2 >= bytes.size

            b = bytes[pixel_start]
            g = bytes[pixel_start + 1]
            r = bytes[pixel_start + 2]
            buf.set(x, y, Color.rgb(r, g, b))
          end
        end

        buf
      end
    end
  end
end
