require "../ui/buffer"

module Opal
  module Game
    # High-performance 60Hz fixed-timestep game loop implementing Glenn Fiedler's
    # "Fix Your Timestep" architecture. Decouples physics/simulation updates
    # from variable-rate terminal frame rendering with interpolation.
    class Loop
      property target_fps : Int32
      property tick_rate : Int32
      getter fps : Float64 = 0.0
      getter ups : Float64 = 0.0
      getter frame_time_ms : Float64 = 0.0
      getter total_frames : UInt64 = 0_u64
      property? running : Bool = false
      property? paused : Bool = false

      @update_callback : (Float64 -> Nil)?
      @render_callback : ((UI::Buffer, Float64) -> Nil)?

      def initialize(@target_fps : Int32 = 60, @tick_rate : Int32 = 60)
      end

      def on_update(&block : Float64 -> Nil) : self
        @update_callback = block
        self
      end

      def on_render(&block : (UI::Buffer, Float64) -> Nil) : self
        @render_callback = block
        self
      end

      def pause : Nil
        @paused = true
      end

      def resume : Nil
        @paused = false
      end

      def stop : Nil
        @running = false
      end

      # Performs a single fixed-timestep update tick (useful for headless testing and step debugging)
      def tick_once(dt : Float64? = nil) : Nil
        fixed_dt = dt || (1.0 / @tick_rate.to_f)
        if cb = @update_callback
          cb.call(fixed_dt)
        end
      end

      # Runs the main loop synchronously until stop is invoked or max_frames is reached
      def run(buffer : UI::Buffer, max_frames : Int32? = nil) : Nil
        @running = true
        fixed_dt = 1.0 / @tick_rate.to_f
        target_frame_dt = 1.0 / @target_fps.to_f
        accumulator = 0.0
        current_time = Time.monotonic
        frame_counter = 0_u64
        update_counter = 0_u64
        fps_timer = current_time

        while @running
          new_time = Time.monotonic
          frame_time = (new_time - current_time).total_seconds
          current_time = new_time

          # Clamp frame time to prevent spiral of death
          frame_time = Math.min(frame_time, 0.25)
          @frame_time_ms = frame_time * 1000.0

          accumulator += frame_time

          # Fixed timestep simulation updates
          while accumulator >= fixed_dt
            unless @paused
              if cb = @update_callback
                cb.call(fixed_dt)
              end
            end
            accumulator -= fixed_dt
            update_counter += 1_u64
          end

          # Variable render with state interpolation alpha
          alpha = accumulator / fixed_dt
          if cb = @render_callback
            cb.call(buffer, alpha)
          end
          frame_counter += 1_u64
          @total_frames += 1_u64

          # Compute FPS and UPS every 500ms
          elapsed_since_fps = (new_time - fps_timer).total_seconds
          if elapsed_since_fps >= 0.5
            @fps = (frame_counter.to_f / elapsed_since_fps).round(1)
            @ups = (update_counter.to_f / elapsed_since_fps).round(1)
            frame_counter = 0_u64
            update_counter = 0_u64
            fps_timer = new_time
          end

          if mf = max_frames
            if @total_frames >= mf
              @running = false
              break
            end
          end

          # Frame rate pacing
          elapsed_frame = (Time.monotonic - new_time).total_seconds
          sleep_time = target_frame_dt - elapsed_frame
          if sleep_time > 0.001
            sleep sleep_time.seconds
          else
            Fiber.yield
          end
        end
      end
    end
  end
end
