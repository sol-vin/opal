require "./pass"
require "./presets"
require "../ui/buffer"

module Opal
  module Shader
    # Multi-pass shader compositing pipeline that applies chained shader passes sequentially
    # across an entire buffer or targeted sub-regions.
    class Pipeline
      getter passes : Array(Pass) = [] of Pass

      def initialize
      end

      def add(pass : Pass) : self
        @passes << pass
        self
      end

      def custom(region : Rect? = nil, &block : ShaderContext -> Nil) : self
        @passes << FragmentPass.new(region, &block)
        self
      end

      def matrix(
        region : Rect? = nil,
        speed : Float64 = 1.0,
        density : Float64 = 0.2,
        lead_color : Color | Symbol | String = :bright_white,
        trail_color : Color | Symbol | String = :green,
        preserve_text : Bool = true,
      ) : self
        @passes << MatrixPass.new(
          region: region,
          speed: speed,
          density: density,
          lead_color: lead_color,
          trail_color: trail_color,
          preserve_text: preserve_text
        )
        self
      end

      def crt(
        region : Rect? = nil,
        intensity : Float64 = 0.35,
        scanline_gap : Int32 = 2,
        phosphor_tint : Color | Symbol | String = Color.none,
        flicker : Bool = true,
      ) : self
        @passes << CrtPass.new(
          region: region,
          intensity: intensity,
          scanline_gap: scanline_gap,
          phosphor_tint: phosphor_tint,
          flicker: flicker
        )
        self
      end

      def glitch(
        region : Rect? = nil,
        intensity : Float64 = 0.2,
        slice_height : Int32 = 3,
        chromatic_shift : Bool = true,
      ) : self
        @passes << GlitchPass.new(
          region: region,
          intensity: intensity,
          slice_height: slice_height,
          chromatic_shift: chromatic_shift
        )
        self
      end

      def plasma(
        region : Rect? = nil,
        scale : Float64 = 0.2,
        speed : Float64 = 1.5,
        shade_bg : Bool = false,
      ) : self
        @passes << PlasmaPass.new(
          region: region,
          scale: scale,
          speed: speed,
          shade_bg: shade_bg
        )
        self
      end

      def fire(region : Rect? = nil, speed : Float64 = 1.0) : self
        @passes << FirePass.new(region: region, speed: speed)
        self
      end

      def starfield(region : Rect? = nil, speed : Float64 = 1.0, count : Int32 = 80, preserve_text : Bool = true) : self
        @passes << StarfieldPass.new(region: region, speed: speed, count: count, preserve_text: preserve_text)
        self
      end

      def ripple(region : Rect? = nil, speed : Float64 = 2.0, frequency : Float64 = 0.4, amplitude : Float64 = 1.5) : self
        @passes << RipplePass.new(region: region, speed: speed, frequency: frequency, amplitude: amplitude)
        self
      end

      def tunnel(region : Rect? = nil, speed : Float64 = 1.2, rotation_speed : Float64 = 0.5) : self
        @passes << TunnelPass.new(region: region, speed: speed, rotation_speed: rotation_speed)
        self
      end

      def vignette(region : Rect? = nil, radius : Float64 = 0.8, falloff : Float64 = 0.5) : self
        @passes << VignettePass.new(region: region, radius: radius, falloff: falloff)
        self
      end

      # Applies all pipeline passes sequentially to the target buffer using ping-pong buffering.
      def apply(buffer : UI::Buffer, time : Float64 = 0.0, frame : UInt64 = 0_u64) : UI::Buffer
        return buffer if @passes.empty?

        src = buffer.clone
        dst = buffer.clone

        @passes.each do |pass|
          next unless pass.enabled?
          pass.apply(src, dst, time, frame)
          # Ping-pong: copy dst back to src for next pass
          src = dst.clone
        end

        # Copy final output back into caller's buffer
        (0...buffer.height).each do |y|
          (0...buffer.width).each do |x|
            buffer.set(x, y, dst.get(x, y))
          end
        end

        buffer
      end
    end
  end
end
