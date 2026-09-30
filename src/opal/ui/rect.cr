module Opal
  module UI
    # A 2D integer bounding box for layouts, clipping, layers, and regions.
    struct Rect
      getter x : Int32
      getter y : Int32
      getter width : Int32
      getter height : Int32

      def initialize(@x : Int32, @y : Int32, @width : Int32, @height : Int32)
      end

      # Convenience constructor for zero-origin rects
      def self.new(width : Int32, height : Int32) : Rect
        new(0, 0, width, height)
      end

      def right : Int32
        @x + @width
      end

      def bottom : Int32
        @y + @height
      end

      def in_bounds?(px : Int32, py : Int32) : Bool
        px >= @x && px < (@x + @width) && py >= @y && py < (@y + @height)
      end

      def contains?(px : Int32, py : Int32) : Bool
        in_bounds?(px, py)
      end

      def contains?(other : Rect) : Bool
        other.x >= @x && other.right <= right && other.y >= @y && other.bottom <= bottom
      end

      def intersects?(other : Rect) : Bool
        @x < other.right && right > other.x && @y < other.bottom && bottom > other.y
      end

      # Computes the intersection of this rect with another rect.
      # If they do not intersect, returns a zero-sized rect.
      def intersection(other : Rect) : Rect
        nx = Math.max(@x, other.x)
        ny = Math.max(@y, other.y)
        nr = Math.min(right, other.right)
        nb = Math.min(bottom, other.bottom)
        nw = Math.max(0, nr - nx)
        nh = Math.max(0, nb - ny)
        Rect.new(nx, ny, nw, nh)
      end

      # Clamps an x-coordinate to lie within this rectangle.
      def clamp_x(px : Int32) : Int32
        px.clamp(@x, Math.max(@x, right - 1))
      end

      # Clamps a y-coordinate to lie within this rectangle.
      def clamp_y(py : Int32) : Int32
        py.clamp(@y, Math.max(@y, bottom - 1))
      end
    end
  end
end
