require "./color"
require "../ui/rect"

module Opal
  # Comprehensive animation and tweening engine for smooth UI transitions,
  # color fading, coordinate motion, and micro-interactions.
  module Animation
    enum Easing
      Linear
      QuadIn
      QuadOut
      QuadInOut
      CubicIn
      CubicOut
      CubicInOut
      SineIn
      SineOut
      SineInOut
      BounceIn
      BounceOut
      BounceInOut
      ElasticIn
      ElasticOut
      ElasticInOut
      BackIn
      BackOut
      BackInOut
    end

    # Mathematical easing functions for smooth animation transitions
    class EasingFunctions
      def self.evaluate(easing : Easing | Symbol, t : Float64) : Float64
        c = t.clamp(0.0, 1.0)
        case easing
        when Easing::Linear, :linear
          c
        when Easing::QuadIn, :ease_in_quad, :quad_in
          c * c
        when Easing::QuadOut, :ease_out_quad, :quad_out
          c * (2.0 - c)
        when Easing::QuadInOut, :ease_in_out_quad, :quad_in_out
          c < 0.5 ? 2.0 * c * c : -1.0 + (4.0 - 2.0 * c) * c
        when Easing::CubicIn, :ease_in_cubic, :cubic_in
          c * c * c
        when Easing::CubicOut, :ease_out_cubic, :cubic_out
          f = c - 1.0
          f * f * f + 1.0
        when Easing::CubicInOut, :ease_in_out_cubic, :cubic_in_out
          c < 0.5 ? 4.0 * c * c * c : (c - 1.0) * (2.0 * c - 2.0) * (2.0 * c - 2.0) + 1.0
        when Easing::SineIn, :sine_in
          1.0 - Math.cos(c * (Math::PI / 2.0))
        when Easing::SineOut, :sine_out
          Math.sin(c * (Math::PI / 2.0))
        when Easing::SineInOut, :sine_in_out
          0.5 * (1.0 - Math.cos(Math::PI * c))
        when Easing::BounceIn, :bounce_in
          1.0 - bounce_out(1.0 - c)
        when Easing::BounceOut, :bounce_out
          bounce_out(c)
        when Easing::BounceInOut, :bounce_in_out
          if c < 0.5
            0.5 * (1.0 - bounce_out(1.0 - c * 2.0))
          else
            0.5 * bounce_out(c * 2.0 - 1.0) + 0.5
          end
        when Easing::ElasticIn, :elastic_in
          return 0.0 if c == 0.0
          return 1.0 if c == 1.0
          -Math.sin(13.0 * (Math::PI / 2.0) * c) * (2.0 ** (10.0 * (c - 1.0)))
        when Easing::ElasticOut, :elastic_out
          return 0.0 if c == 0.0
          return 1.0 if c == 1.0
          Math.sin(-13.0 * (Math::PI / 2.0) * (c + 1.0)) * (2.0 ** (-10.0 * c)) + 1.0
        when Easing::ElasticInOut, :elastic_in_out
          return 0.0 if c == 0.0
          return 1.0 if c == 1.0
          if c < 0.5
            0.5 * Math.sin(13.0 * (Math::PI / 2.0) * (2.0 * c)) * (2.0 ** (10.0 * (2.0 * c - 1.0)))
          else
            0.5 * (Math.sin(-13.0 * (Math::PI / 2.0) * (2.0 * c - 1.0 + 1.0)) * (2.0 ** (-10.0 * (2.0 * c - 1.0))) + 2.0)
          end
        when Easing::BackIn, :back_in
          s = 1.70158
          c * c * ((s + 1.0) * c - s)
        when Easing::BackOut, :back_out
          s = 1.70158
          f = c - 1.0
          f * f * ((s + 1.0) * f + s) + 1.0
        when Easing::BackInOut, :back_in_out
          s = 1.70158 * 1.525
          c2 = c * 2.0
          if c2 < 1.0
            0.5 * (c2 * c2 * ((s + 1.0) * c2 - s))
          else
            f = c2 - 2.0
            0.5 * (f * f * ((s + 1.0) * f + s) + 2.0)
          end
        else
          c
        end
      end

      private def self.bounce_out(t : Float64) : Float64
        n1 = 7.5625
        d1 = 2.75

        if t < 1.0 / d1
          n1 * t * t
        elsif t < 2.0 / d1
          t2 = t - (1.5 / d1)
          n1 * t2 * t2 + 0.75
        elsif t < 2.5 / d1
          t3 = t - (2.25 / d1)
          n1 * t3 * t3 + 0.9375
        else
          t4 = t - (2.625 / d1)
          n1 * t4 * t4 + 0.984375
        end
      end
    end

    # Easing module functions for backwards compatibility
    def self.linear(t : Float64) : Float64
      EasingFunctions.evaluate(Easing::Linear, t)
    end

    def self.ease_in_quad(t : Float64) : Float64
      EasingFunctions.evaluate(Easing::QuadIn, t)
    end

    def self.ease_out_quad(t : Float64) : Float64
      EasingFunctions.evaluate(Easing::QuadOut, t)
    end

    def self.ease_in_out_quad(t : Float64) : Float64
      EasingFunctions.evaluate(Easing::QuadInOut, t)
    end

    def self.ease_in_cubic(t : Float64) : Float64
      EasingFunctions.evaluate(Easing::CubicIn, t)
    end

    def self.ease_out_cubic(t : Float64) : Float64
      EasingFunctions.evaluate(Easing::CubicOut, t)
    end

    def self.ease_in_out_cubic(t : Float64) : Float64
      EasingFunctions.evaluate(Easing::CubicInOut, t)
    end

    def self.elastic_out(t : Float64) : Float64
      EasingFunctions.evaluate(Easing::ElasticOut, t)
    end

    def self.bounce_out(t : Float64) : Float64
      EasingFunctions.evaluate(Easing::BounceOut, t)
    end

    def self.ease(type : Symbol, t : Float64) : Float64
      EasingFunctions.evaluate(type, t)
    end

    # Flexible numeric animator supporting both delta updates and wall-clock timestamps
    class Tween
      property from : Float64
      property to : Float64
      property duration_ms : Int64
      property duration : Time::Span
      property easing : Easing
      getter current_val : Float64
      getter elapsed : Float64 = 0.0
      property? finished : Bool = false
      property? yoyo : Bool = false
      property? looping : Bool = false
      getter start_time : Time::Instant

      @on_update_proc : (Float64 -> Nil)?
      @on_complete_proc : (-> Nil)?

      # Modern span/delta constructor
      def initialize(
        from_val : Float64,
        to_val : Float64,
        duration : Time::Span,
        easing : Easing | Symbol = Easing::Linear,
        @yoyo : Bool = false,
        @looping : Bool = false,
      )
        @from = from_val
        @to = to_val
        @duration = duration
        @duration_ms = duration.total_milliseconds.to_i64
        @easing = easing.is_a?(Easing) ? easing : Easing::Linear
        @current_val = from_val
        @start_time = Time.instant
      end

      # Legacy ms/instant constructor
      def initialize(
        @from : Float64,
        @to : Float64,
        @duration_ms : Int64 = 300_i64,
        easing : Symbol = :ease_out_quad,
        @start_time : Time::Instant = Time.instant,
      )
        @duration = @duration_ms.milliseconds
        @easing = Easing::QuadOut
        @current_val = @from
      end

      def on_update(&block : Float64 -> Nil) : self
        @on_update_proc = block
        self
      end

      def on_complete(&block : -> Nil) : self
        @on_complete_proc = block
        self
      end

      def progress : Float64
        total_sec = @duration.total_seconds
        return 1.0 if total_sec <= 0.0
        (@elapsed / total_sec).clamp(0.0, 1.0)
      end

      def update(dt : Float64) : Float64
        return @current_val if @finished

        @elapsed += dt
        p = progress
        eased_p = EasingFunctions.evaluate(@easing, p)
        @current_val = @from + (@to - @from) * eased_p

        @on_update_proc.try(&.call(@current_val))

        if p >= 1.0
          if @looping
            @elapsed = 0.0
            if @yoyo
              temp = @from
              @from = @to
              @to = temp
            end
          else
            @finished = true
            @current_val = @to
            @on_complete_proc.try(&.call)
          end
        end

        @current_val
      end

      def current_value(now : Time::Instant = Time.instant) : Float64
        elapsed_ms = (now - @start_time).total_milliseconds
        if elapsed_ms <= 0.0
          @from
        elsif elapsed_ms >= @duration_ms
          @to
        else
          t = elapsed_ms / @duration_ms.to_f
          eased_t = EasingFunctions.evaluate(@easing, t)
          @from + (@to - @from) * eased_t
        end
      end

      def finished?(now : Time::Instant = Time.instant) : Bool
        @finished || ((now - @start_time).total_milliseconds >= @duration_ms)
      end
    end

    # Color tween interpolating between two colors
    class ColorTween
      getter tween : Tween
      getter from_color : Color
      getter to_color : Color

      def initialize(@from_color : Color, @to_color : Color, duration : Time::Span, easing : Easing = Easing::Linear)
        @tween = Tween.new(0.0, 1.0, duration, easing)
      end

      def current_color : Color
        Color.lerp(@from_color, @to_color, @tween.current_val)
      end

      def update(dt : Float64) : Color
        @tween.update(dt)
        current_color
      end

      def finished? : Bool
        @tween.finished?
      end
    end

    # Rect tween interpolating between two rectangles
    class RectTween
      getter tween : Tween
      getter from_rect : UI::Rect
      getter to_rect : UI::Rect

      def initialize(@from_rect : UI::Rect, @to_rect : UI::Rect, duration : Time::Span, easing : Easing = Easing::Linear)
        @tween = Tween.new(0.0, 1.0, duration, easing)
      end

      def current_rect : UI::Rect
        t = @tween.current_val
        rx = (@from_rect.x.to_f + (@to_rect.x.to_f - @from_rect.x.to_f) * t).round.to_i
        ry = (@from_rect.y.to_f + (@to_rect.y.to_f - @from_rect.y.to_f) * t).round.to_i
        rw = (@from_rect.width.to_f + (@to_rect.width.to_f - @from_rect.width.to_f) * t).round.to_i
        rh = (@from_rect.height.to_f + (@to_rect.height.to_f - @from_rect.height.to_f) * t).round.to_i
        UI::Rect.new(rx, ry, rw, rh)
      end

      def update(dt : Float64) : UI::Rect
        @tween.update(dt)
        current_rect
      end

      def finished? : Bool
        @tween.finished?
      end
    end
  end
end
