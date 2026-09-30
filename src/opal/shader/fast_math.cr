module Opal
  module Shader
    # High-performance mathematical helpers and trigonometric lookup tables (LUT)
    # for real-time text fragment shaders.
    module FastMath
      TABLE_SIZE = 1024
      TWO_PI     = Math::PI * 2.0
      HALF_PI    = Math::PI / 2.0

      # Precomputed sine lookup table
      SIN_TABLE = Slice(Float64).new(TABLE_SIZE) do |i|
        Math.sin(i.to_f * TWO_PI / TABLE_SIZE.to_f)
      end

      # Constant-time sine approximation via lookup table
      def self.sin(angle : Float64) : Float64
        # Normalize angle to [0.0, 1.0)
        norm = (angle % TWO_PI) / TWO_PI
        norm += 1.0 if norm < 0.0
        idx = (norm * TABLE_SIZE.to_f).to_i % TABLE_SIZE
        SIN_TABLE.unsafe_fetch(idx)
      end

      # Constant-time cosine approximation via lookup table
      def self.cos(angle : Float64) : Float64
        sin(angle + HALF_PI)
      end
    end
  end
end
