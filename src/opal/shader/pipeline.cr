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

      def raymarch_sphere(
        region : Rect? = nil,
        speed : Float64 = 1.0,
        radius : Float64 = 0.75,
        sphere_color : Color | Symbol | String = :bright_cyan,
        light_color : Color | Symbol | String = :white,
        preserve_text : Bool = false,
      ) : self
        @passes << RaymarchSpherePass.new(
          region: region,
          speed: speed,
          radius: radius,
          sphere_color: sphere_color,
          light_color: light_color,
          preserve_text: preserve_text
        )
        self
      end

      def voronoi(
        region : Rect? = nil,
        speed : Float64 = 0.8,
        scale : Float64 = 0.15,
        border_color : Color | Symbol | String = :bright_cyan,
        inner_color : Color | Symbol | String = :blue,
      ) : self
        @passes << VoronoiPass.new(
          region: region,
          speed: speed,
          scale: scale,
          border_color: border_color,
          inner_color: inner_color
        )
        self
      end

      def fractal_landscape(
        region : Rect? = nil,
        speed : Float64 = 1.0,
        sky_color : Color | Symbol | String = :dark_gray,
        mountain_color : Color | Symbol | String = :blue,
        ridge_color : Color | Symbol | String = :magenta,
        foreground_color : Color | Symbol | String = :bright_cyan,
      ) : self
        @passes << FractalLandscapePass.new(
          region: region,
          speed: speed,
          sky_color: sky_color,
          mountain_color: mountain_color,
          ridge_color: ridge_color,
          foreground_color: foreground_color
        )
        self
      end

      def audio_visualizer(
        region : Rect? = nil,
        speed : Float64 = 1.0,
        bar_count : Int32 = 16,
        low_color : Color | Symbol | String = :green,
        mid_color : Color | Symbol | String = :yellow,
        high_color : Color | Symbol | String = :bright_red,
        peak_color : Color | Symbol | String = :bright_white,
      ) : self
        @passes << AudioVisualizerPass.new(
          region: region,
          speed: speed,
          bar_count: bar_count,
          low_color: low_color,
          mid_color: mid_color,
          high_color: high_color,
          peak_color: peak_color
        )
        self
      end

      # Applies all pipeline passes sequentially to the target buffer using ping-pong buffering.
      def apply(buffer : UI::Buffer, time : Float64 = 0.0, frame : UInt64 = 0_u64) : UI::Buffer
        return buffer if @passes.empty?

        buf_a = buffer.clone
        buf_b = buffer.clone

        src = buf_a
        dst = buf_b

        @passes.each do |pass|
          next unless pass.enabled?
          dst.copy_from(src)
          pass.apply(src, dst, time, frame)
          src, dst = dst, src
        end

        # Copy final output back into caller's buffer
        buffer.copy_from(src)
        buffer
      end
    end
  end
end
