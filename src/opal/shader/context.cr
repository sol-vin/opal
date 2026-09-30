require "../ui/cell"
require "../ui/buffer"
require "../style/color"
require "../ui/rect"
require "./fast_math"

module Opal
  module Shader
    # 2D rectangular bounding box for region-scoped shader passes
    alias Rect = UI::Rect

    # Execution context provided to a text fragment shader for each evaluated cell.
    class ShaderContext
      property x : Int32
      property y : Int32
      property u : Float64
      property v : Float64
      property local_x : Int32
      property local_y : Int32
      property local_u : Float64
      property local_v : Float64
      property width : Int32
      property height : Int32
      property region_width : Int32
      property region_height : Int32
      property time : Float64
      property frame : UInt64
      property source_buffer : UI::Buffer
      property cell : UI::Cell
      property? discarded : Bool = false

      def initialize(
        @x : Int32,
        @y : Int32,
        @local_x : Int32,
        @local_y : Int32,
        @width : Int32,
        @height : Int32,
        @region_width : Int32,
        @region_height : Int32,
        @time : Float64,
        @frame : UInt64,
        @source_buffer : UI::Buffer,
        @cell : UI::Cell,
      )
        @u = @width > 1 ? (@x.to_f / (@width - 1)) : 0.0
        @v = @height > 1 ? (@y.to_f / (@height - 1)) : 0.0
        @local_u = @region_width > 1 ? (@local_x.to_f / (@region_width - 1)) : 0.0
        @local_v = @region_height > 1 ? (@local_y.to_f / (@region_height - 1)) : 0.0
      end

      # Mutates context in-place to avoid per-cell heap allocations during fragment shader passes
      def reset(
        x : Int32,
        y : Int32,
        local_x : Int32,
        local_y : Int32,
        width : Int32,
        height : Int32,
        region_width : Int32,
        region_height : Int32,
        time : Float64,
        frame : UInt64,
        source_buffer : UI::Buffer,
        cell : UI::Cell,
      ) : Nil
        @x = x
        @y = y
        @local_x = local_x
        @local_y = local_y
        @width = width
        @height = height
        @region_width = region_width
        @region_height = region_height
        @time = time
        @frame = frame
        @source_buffer = source_buffer
        @cell = cell
        @discarded = false

        @u = @width > 1 ? (@x.to_f / (@width - 1)) : 0.0
        @v = @height > 1 ? (@y.to_f / (@height - 1)) : 0.0
        @local_u = @region_width > 1 ? (@local_x.to_f / (@region_width - 1)) : 0.0
        @local_v = @region_height > 1 ? (@local_y.to_f / (@region_height - 1)) : 0.0
      end

      # Character getter & setter
      def char : Char
        @cell.char
      end

      def char=(ch : Char)
        @cell.char = ch
      end

      # Foreground color getter & setter
      def fg : Color
        @cell.fg
      end

      def fg=(color : Color)
        @cell.fg = color
      end

      # Background color getter & setter
      def bg : Color
        @cell.bg
      end

      def bg=(color : Color)
        @cell.bg = color
      end

      # Attribute flags
      def bold? : Bool
        @cell.bold?
      end

      def bold=(val : Bool)
        @cell.bold = val
      end

      def bold! : Nil
        @cell.bold = true
      end

      def dim? : Bool
        @cell.dim?
      end

      def dim=(val : Bool)
        @cell.dim = val
      end

      def dim! : Nil
        @cell.dim = true
      end

      def italic? : Bool
        @cell.italic?
      end

      def italic=(val : Bool)
        @cell.italic = val
      end

      def underline? : Bool
        @cell.underline?
      end

      def underline=(val : Bool)
        @cell.underline = val
      end

      def reverse? : Bool
        @cell.reverse?
      end

      def reverse=(val : Bool)
        @cell.reverse = val
      end

      def invert! : Nil
        old_fg = @cell.fg
        @cell.fg = @cell.bg
        @cell.bg = old_fg
      end

      # Interpolates active foreground color toward target color
      def lerp_fg(target : Color, factor : Float64) : Nil
        @cell.fg = Color.lerp(@cell.fg, target, factor)
      end

      # Interpolates active background color toward target color
      def lerp_bg(target : Color, factor : Float64) : Nil
        @cell.bg = Color.lerp(@cell.bg, target, factor)
      end

      # Samples another cell from the input source buffer
      def sample(sx : Int32, sy : Int32) : UI::Cell
        @source_buffer.get(sx, sy)
      end

      # Samples only the character from the input source buffer
      def sample_char(sx : Int32, sy : Int32) : Char
        @source_buffer.get(sx, sy).char
      end

      # Samples only the foreground color from the input source buffer
      def sample_fg(sx : Int32, sy : Int32) : Color
        @source_buffer.get(sx, sy).fg
      end

      # Replaces current cell state entirely from another cell
      def replace_from(other : UI::Cell) : Nil
        @cell = other
      end

      # Procedural trigonometric wave functions (accelerated via FastMath LUT)
      def wave(freq : Float64 = 1.0, speed : Float64 = 1.0) : Float64
        FastMath.sin(@u * freq + @time * speed)
      end

      def wave_y(freq : Float64 = 1.0, speed : Float64 = 1.0) : Float64
        FastMath.sin(@v * freq + @time * speed)
      end

      # Fast deterministic pseudo-random float between 0.0 and 1.0
      def noise : Float64
        t_int = (@time * 1000.0).to_i64 rescue 0_i64
        s = (@x.to_i64 &* 374761393_i64) ^ (@y.to_i64 &* 668265263_i64) ^ (t_int &* 1274126177_i64)
        s = (s ^ (s >> 13)) &* 1274126177_i64
        ((s.abs & 0xFFFFFF).to_f / 0xFFFFFF.to_f)
      end

      # Distance from center (0.5, 0.5)
      def dist_center : Float64
        dx = (@u - 0.5) * 2.0
        dy = (@v - 0.5) * 2.0
        Math.sqrt(dx * dx + dy * dy)
      end

      # Distance from specific normalized coordinates (cx, cy)
      def dist_from(cx : Float64, cy : Float64) : Float64
        dx = (@u - cx) * 2.0
        dy = (@v - cy) * 2.0
        Math.sqrt(dx * dx + dy * dy)
      end

      # Discards current cell modifications
      def discard : Nil
        @discarded = true
      end
    end
  end
end
