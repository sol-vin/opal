module Opal
  module Animation
    # Active tween controller tracking a target property with update and completion callbacks.
    class ActiveTween
      getter tween : Tween
      getter on_update : Proc(Float64, Nil)
      getter on_complete : Proc(Nil)?

      def initialize(
        @tween : Tween,
        @on_complete : Proc(Nil)? = nil,
        &@on_update : Float64 -> Nil
      )
      end

      def update(now : Time::Instant = Time.instant) : Bool
        val = @tween.current_value(now)
        @on_update.call(val)
        if @tween.finished?(now)
          @on_complete.try(&.call)
          true
        else
          false
        end
      end
    end

    # Central animation orchestrator managing tween updates per frame.
    class Animator
      getter tweens : Hash(String, ActiveTween)

      def initialize
        @tweens = {} of String => ActiveTween
      end

      # Starts or updates a named tween animation
      def animate(
        name : String,
        from from_val : Number,
        to to_val : Number,
        duration : Time::Span = 300.milliseconds,
        easing : Symbol = :ease_out_cubic,
        now : Time::Instant = Time.instant,
        on_complete : Proc(Nil)? = nil,
        &on_update : Float64 -> Nil
      ) : self
        tw = Tween.new(
          from: from_val.to_f,
          to: to_val.to_f,
          duration_ms: duration.total_milliseconds.to_i64,
          easing: easing,
          start_time: now
        )
        @tweens[name] = ActiveTween.new(
          tween: tw,
          on_complete: on_complete,
          &on_update
        )
        self
      end

      # Advances all active animations by timestamp
      def tick(now : Time::Instant = Time.instant) : Nil
        completed = [] of String
        @tweens.each do |name, at|
          is_done = at.update(now)
          completed << name if is_done
        end
        completed.each { |name| @tweens.delete(name) }
      end

      def running? : Bool
        !@tweens.empty?
      end

      def cancel(name : String) : self
        @tweens.delete(name)
        self
      end

      def clear : self
        @tweens.clear
        self
      end
    end
  end
end
