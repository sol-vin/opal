module Opal
  module Shader
    # High-performance mathematical helpers and trigonometric lookup tables (LUT)
    # for real-time text fragment shaders.
    module FastMath
      TABLE_SIZE  = 1024
      TABLE_MASK  = 1023
      TWO_PI      = Math::PI * 2.0
      INV_TWO_PI  = 1.0 / TWO_PI
      HALF_PI     = Math::PI / 2.0
      TABLE_SCALE = 1024.0

      # Precomputed sine lookup table
      SIN_TABLE = Slice(Float64).new(TABLE_SIZE) do |i|
        Math.sin(i.to_f * TWO_PI / TABLE_SIZE.to_f)
      end

      # Constant-time sine approximation via lookup table without fmod or division
      def self.sin(angle : Float64) : Float64
        norm = angle * INV_TWO_PI
        norm -= norm.floor
        idx = (norm * TABLE_SCALE).to_i & TABLE_MASK
        SIN_TABLE.unsafe_fetch(idx)
      end

      # Constant-time cosine approximation via lookup table
      def self.cos(angle : Float64) : Float64
        sin(angle + HALF_PI)
      end
    end
  end
end
