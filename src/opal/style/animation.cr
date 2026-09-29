module Opal
  # Animation and tweening engine for smooth UI transitions and micro-interactions.
  module Animation
    # Common easing functions mapping progress t (0.0 to 1.0) to transformed values.
    def self.linear(t : Float64) : Float64
      t.clamp(0.0, 1.0)
    end

    def self.ease_in_quad(t : Float64) : Float64
      c = t.clamp(0.0, 1.0)
      c * c
    end

    def self.ease_out_quad(t : Float64) : Float64
      c = t.clamp(0.0, 1.0)
      c * (2.0 - c)
    end

    def self.ease_in_out_quad(t : Float64) : Float64
      c = t.clamp(0.0, 1.0)
      if c < 0.5
        2.0 * c * c
      else
        -1.0 + (4.0 - 2.0 * c) * c
      end
    end

    def self.ease_in_cubic(t : Float64) : Float64
      c = t.clamp(0.0, 1.0)
      c * c * c
    end

    def self.ease_out_cubic(t : Float64) : Float64
      c = t.clamp(0.0, 1.0) - 1.0
      c * c * c + 1.0
    end

    def self.ease_in_out_cubic(t : Float64) : Float64
      c = t.clamp(0.0, 1.0)
      if c < 0.5
        4.0 * c * c * c
      else
        (c - 1.0) * (2.0 * c - 2.0) * (2.0 * c - 2.0) + 1.0
      end
    end

    def self.elastic_out(t : Float64) : Float64
      c = t.clamp(0.0, 1.0)
      return 0.0 if c == 0.0
      return 1.0 if c == 1.0
      p = 0.3
      s = p / 4.0
      (2.0 ** (-10.0 * c)) * Math.sin((c - s) * (2.0 * Math::PI) / p) + 1.0
    end

    def self.bounce_out(t : Float64) : Float64
      c = t.clamp(0.0, 1.0)
      n1 = 7.5625
      d1 = 2.75

      if c < 1.0 / d1
        n1 * c * c
      elsif c < 2.0 / d1
        c2 = c - (1.5 / d1)
        n1 * c2 * c2 + 0.75
      elsif c < 2.5 / d1
        c2 = c - (2.25 / d1)
        n1 * c2 * c2 + 0.9375
      else
        c2 = c - (2.625 / d1)
        n1 * c2 * c2 + 0.984375
      end
    end

    # Resolves an easing function by symbol
    def self.ease(type : Symbol, t : Float64) : Float64
      case type
      when :linear            then linear(t)
      when :ease_in_quad      then ease_in_quad(t)
      when :ease_out_quad     then ease_out_quad(t)
      when :ease_in_out_quad  then ease_in_out_quad(t)
      when :ease_in_cubic     then ease_in_cubic(t)
      when :ease_out_cubic    then ease_out_cubic(t)
      when :ease_in_out_cubic then ease_in_out_cubic(t)
      when :elastic_out       then elastic_out(t)
      when :bounce_out        then bounce_out(t)
      else                         linear(t)
      end
    end

    # Represents a time-based numeric interpolation between two values.
    class Tween
      getter from : Float64
      getter to : Float64
      getter duration_ms : Int64
      getter easing : Symbol
      getter start_time : Time::Instant

      def initialize(
        @from : Float64,
        @to : Float64,
        @duration_ms : Int64 = 300_i64,
        @easing : Symbol = :ease_out_quad,
        @start_time : Time::Instant = Time.instant,
      )
      end

      def current_value(now : Time::Instant = Time.instant) : Float64
        elapsed_ms = (now - @start_time).total_milliseconds
        if elapsed_ms <= 0.0
          @from
        elsif elapsed_ms >= @duration_ms
          @to
        else
          t = elapsed_ms / @duration_ms.to_f
          eased_t = Animation.ease(@easing, t)
          @from + (@to - @from) * eased_t
        end
      end

      def finished?(now : Time::Instant = Time.instant) : Bool
        (now - @start_time).total_milliseconds >= @duration_ms
      end
    end
  end
end
