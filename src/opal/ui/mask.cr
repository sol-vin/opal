require "./rect"
require "../style/color"

module Opal
  module UI
    # A 2D normalized weight map (values from 0.0 to 1.0) used for alpha stencil masking,
    # spotlights, and feathered dithering effects in terminal screen buffers.
    class MaskMap
      getter width : Int32
      getter height : Int32
      getter weights : Array(Float64)

      # Shading characters for dithering fractional alpha values: 0.0 -> 1.0
      DITHER_CHARS = Opal::Glyphs::Shades

      def initialize(@width : Int32, @height : Int32, initial_weight : Float64 = 1.0)
        @weights = Array(Float64).new(@width * @height, initial_weight.clamp(0.0, 1.0))
      end

      def in_bounds?(x : Int32, y : Int32) : Bool
        x >= 0 && x < @width && y >= 0 && y < @height
      end

      def get(x : Int32, y : Int32) : Float64
        return 0.0 unless in_bounds?(x, y)
        @weights[y * @width + x]
      end

      def [](x : Int32, y : Int32) : Float64
        get(x, y)
      end

      def set(x : Int32, y : Int32, weight : Float64) : Nil
        return unless in_bounds?(x, y)
        @weights[y * @width + x] = weight.clamp(0.0, 1.0)
      end

      def []=(x : Int32, y : Int32, weight : Float64) : Nil
        set(x, y, weight)
      end

      def fill(weight : Float64) : Nil
        @weights.fill(weight.clamp(0.0, 1.0))
      end

      # Inverts all mask weights (1.0 - weight)
      def invert : MaskMap
        inverted = MaskMap.new(@width, @height)
        @weights.each_with_index do |w, i|
          inverted.weights[i] = 1.0 - w
        end
        inverted
      end

      # Blends this mask with another mask using :multiply, :screen, :add, or :subtract
      def blend(other : MaskMap, mode : Symbol = :multiply) : MaskMap
        w = Math.min(@width, other.width)
        h = Math.min(@height, other.height)
        result = MaskMap.new(w, h)

        (0...h).each do |y|
          (0...w).each do |x|
            a = get(x, y)
            b = other.get(x, y)
            val = case mode
                  when :multiply then a * b
                  when :screen   then 1.0 - (1.0 - a) * (1.0 - b)
                  when :add      then (a + b).clamp(0.0, 1.0)
                  when :subtract then (a - b).clamp(0.0, 1.0)
                  else                a * b
                  end
            result.set(x, y, val)
          end
        end
        result
      end

      # Returns a dither shade character for a given alpha weight (0.0..1.0)
      def self.dither_char(weight : Float64) : Char
        idx = (weight.clamp(0.0, 1.0) * (DITHER_CHARS.size - 1)).round.to_i
        DITHER_CHARS[idx]
      end

      # Generates a circular or elliptical radial mask centered at (cx, cy) with optional feathering.
      # Terminal cells have an aspect ratio of roughly 2:1 (height:width), which is compensated for.
      def self.radial(
        cx : Float64 | Int32,
        cy : Float64 | Int32,
        radius : Float64,
        feather : Float64 = 0.0,
        width : Int32 = 80,
        height : Int32 = 25,
        aspect_ratio : Float64 = 2.0,
      ) : MaskMap
        map = MaskMap.new(width, height, 0.0)
        fcx = cx.to_f
        fcy = cy.to_f
        inner_radius = Math.max(0.0, radius - feather)

        (0...height).each do |y|
          (0...width).each do |x|
            dx = x.to_f - fcx
            dy = (y.to_f - fcy) * aspect_ratio
            dist = Math.sqrt(dx * dx + dy * dy)

            if dist <= inner_radius
              map.set(x, y, 1.0)
            elsif dist >= radius
              map.set(x, y, 0.0)
            else
              # Linear interpolation across feather zone
              if feather > 0.0
                t = (radius - dist) / feather
                map.set(x, y, t.clamp(0.0, 1.0))
              else
                map.set(x, y, 0.0)
              end
            end
          end
        end
        map
      end

      # Generates a linear gradient mask along a specified angle (in degrees, 0 = left-to-right, 90 = top-to-bottom)
      def self.linear_gradient(
        angle_degrees : Float64,
        width : Int32 = 80,
        height : Int32 = 25,
        start_val : Float64 = 0.0,
        end_val : Float64 = 1.0,
      ) : MaskMap
        map = MaskMap.new(width, height, 0.0)
        rad = angle_degrees * Math::PI / 180.0
        cos_a = Math.cos(rad)
        sin_a = Math.sin(rad)

        # Center normalized coordinates
        max_dim = Math.sqrt(width.to_f**2 + height.to_f**2) / 2.0

        (0...height).each do |y|
          (0...width).each do |x|
            cx = x.to_f - (width / 2.0)
            cy = y.to_f - (height / 2.0)
            proj = (cx * cos_a + cy * sin_a) / max_dim
            norm = ((proj + 1.0) / 2.0).clamp(0.0, 1.0)
            weight = start_val + (end_val - start_val) * norm
            map.set(x, y, weight)
          end
        end
        map
      end

      # Generates a rectangular box mask with optional feathering around its perimeter
      def self.box(
        bx : Int32,
        by : Int32,
        bw : Int32,
        bh : Int32,
        feather : Float64 = 0.0,
        width : Int32 = 80,
        height : Int32 = 25,
      ) : MaskMap
        map = MaskMap.new(width, height, 0.0)
        right = bx + bw
        bottom = by + bh

        (0...height).each do |y|
          (0...width).each do |x|
            if x >= bx && x < right && y >= by && y < bottom
              if feather <= 0.0
                map.set(x, y, 1.0)
              else
                dist_left = (x - bx).to_f
                dist_right = (right - 1 - x).to_f
                dist_top = (y - by).to_f
                dist_bottom = (bottom - 1 - y).to_f
                min_edge = [dist_left, dist_right, dist_top, dist_bottom].min
                weight = (min_edge / feather).clamp(0.0, 1.0)
                map.set(x, y, weight)
              end
            else
              map.set(x, y, 0.0)
            end
          end
        end
        map
      end

      # Generates a stencil mask from an array of ASCII strings (non-space characters become 1.0)
      def self.stencil(lines : Array(String), width : Int32? = nil, height : Int32? = nil) : MaskMap
        h = height || lines.size
        w = width || (lines.map(&.size).max? || 0)
        map = MaskMap.new(Math.max(1, w), Math.max(1, h), 0.0)

        lines.each_with_index do |line, y|
          break if y >= map.height
          line.each_char_with_index do |ch, x|
            break if x >= map.width
            map.set(x, y, ch == ' ' ? 0.0 : 1.0)
          end
        end
        map
      end

      # Generates a checkerboard mask pattern
      def self.checkerboard(tile_w : Int32 = 4, tile_h : Int32 = 2, width : Int32 = 80, height : Int32 = 25) : MaskMap
        map = MaskMap.new(width, height, 0.0)
        (0...height).each do |y|
          (0...width).each do |x|
            tx = (x / Math.max(1, tile_w)) % 2
            ty = (y / Math.max(1, tile_h)) % 2
            map.set(x, y, (tx ^ ty) == 0 ? 1.0 : 0.0)
          end
        end
        map
      end
    end
  end
end
