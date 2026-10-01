require "./writer"
require "../ui/buffer"

module Opal
  module Asciicast
    # Screen recorder that captures `Opal::UI::Buffer` frames directly into
    # standard Asciinema v2 (.cast) files without flicker or terminal diff artifacts.
    class ScreenRecorder
      getter writer : Writer
      property output_path : String
      getter? active : Bool = false
      getter? paused : Bool = false
      getter frame_count : Int32 = 0
      property skip_frames_remaining : Int32 = 0
      getter last_captured_buffer : UI::Buffer? = nil
      @last_frame_time : Time::Instant? = nil
      @min_frame_interval : Float64 = 0.016 # ~60fps maximum rate
      @last_buffer_hash : UInt64? = nil

      def recording? : Bool
        @active
      end

      def current_time : Float64
        @writer.current_time
      end

      def initialize(
        @output_path : String,
        width : Int32 = 80,
        height : Int32 = 24,
        title : String = "Opal Session",
        term : String = "xterm-256color",
        writer : Writer? = nil,
      )
        @writer = writer || Writer.new(width: width, height: height, title: title, term: term)
      end

      # Starts the recording session
      def start : self
        @active = true
        @paused = false
        @last_frame_time = Time.instant
        self
      end

      # Captures a screen buffer frame directly.
      # If `advance` is not specified, calculates elapsed wall-clock time since last frame.
      def capture_frame(buffer : UI::Buffer, advance : Float64? = nil) : Bool
        return false unless @active
        return false if @paused

        if @skip_frames_remaining > 0
          @skip_frames_remaining -= 1
          return false
        end

        buf_hash = buffer.to_s.hash
        if advance == 0.0 && @last_buffer_hash == buf_hash
          return false
        end

        delta = if adv = advance
                  adv
                elsif last = @last_frame_time
                  now = Time.instant
                  d = (now - last).total_seconds
                  @last_frame_time = now
                  Math.max(d, @min_frame_interval)
                else
                  @last_frame_time = Time.instant
                  0.05
                end

        @writer.draw_buffer(buffer, advance: delta)
        @last_captured_buffer = buffer
        @last_buffer_hash = buf_hash
        @frame_count += 1
        true
      end

      # Captures a screenshot of the last recorded frame (or the passed buffer).
      def screenshot(
        path : String? = nil,
        format : Symbol = :ansi,
        buffer : UI::Buffer? = nil,
        copy_to_clipboard : Bool = false,
      ) : String
        target = buffer || @last_captured_buffer || UI::Buffer.new(@writer.width, @writer.height)
        target.screenshot(path: path, format: format, copy_to_clipboard: copy_to_clipboard)
      end

      # Captures a screenshot of the last recorded frame and copies it to the system clipboard.
      def screenshot_to_clipboard(format : Symbol = :text, buffer : UI::Buffer? = nil) : String
        screenshot(format: format, buffer: buffer, copy_to_clipboard: true)
      end

      # Pauses recording. Subsequent frame captures are ignored until `resume` is called.
      def pause : self
        @paused = true
        self
      end

      # Resumes recording after being paused.
      def resume : self
        @paused = false
        @last_frame_time = Time.instant
        self
      end

      # Advances the recording timeline by simulating N frames.
      def wait_frames(count : Int32 = 1, delay_per_frame : Float64 = 0.05) : self
        return self unless @active
        @writer.pause(Math.max(0, count) * delay_per_frame)
        self
      end

      # Instructs the recorder to discard the next N captured frames.
      def skip_frames(count : Int32) : self
        @skip_frames_remaining += Math.max(0, count)
        self
      end

      # Freezes/holds the current visual frame for a given number of seconds in playback.
      def hold(seconds : Float64) : self
        return self unless @active
        @writer.pause(Math.max(0.0, seconds))
        self
      end

      # Writes raw terminal output or control sequences directly to the recording timeline.
      def write_terminal(data : String, delay : Float64 = 0.0) : self
        return self unless @active
        @writer.write(data, delay)
        self
      end

      # Simulates human keystroke typing directly to the recording timeline.
      def type_text(text : String, cps : Float64 = 25.0) : self
        return self unless @active
        @writer.type_text(text, cps: cps)
        self
      end

      # Stops the recording session and saves the .cast file.
      def stop : self
        return self unless @active
        @active = false
        @writer.save(@output_path)
        self
      end

      # Saves the recording to disk. If path is provided, overrides @output_path.
      def save(path : String? = nil) : Nil
        target = path || @output_path
        @writer.save(target)
      end

      # Convenience scoped recording block. Automatically starts and stops recording.
      def record(&block : ScreenRecorder -> Nil) : Nil
        start
        begin
          with self yield self
        ensure
          stop
        end
      end
    end
  end
end
