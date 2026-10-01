require "./screen_recorder"
require "./playback_engine"

module Opal
  module Asciicast
    # VCR-style tactile tape deck supporting programmatic and interactive
    # recording and playback of asciicast sessions with multi-frame pacing and overlay awareness.
    class VCR
      # Global default VCR singleton instance
      @@instance : VCR? = nil

      def self.instance : VCR
        @@instance ||= new
      end

      # Delegate class-level methods to the global singleton instance
      def self.record(
        path : String,
        width : Int32 = 80,
        height : Int32 = 24,
        title : String = "Opal Session",
        term : String = "xterm-256color",
        &
      ) : VCR
        instance.record(path, width: width, height: height, title: title, term: term) do |v|
          with v yield v
        end
      end

      def self.record(
        path : String,
        width : Int32 = 80,
        height : Int32 = 24,
        title : String = "Opal Session",
        term : String = "xterm-256color",
      ) : VCR
        instance.record(path, width: width, height: height, title: title, term: term)
      end

      def self.capture(buffer : UI::Buffer, advance : Float64? = nil) : Bool
        instance.capture(buffer, advance)
      end

      def self.wait_frames(count : Int32 = 1, delay_per_frame : Float64 = 0.05) : VCR
        instance.wait_frames(count, delay_per_frame)
      end

      def self.skip_frames(count : Int32) : VCR
        instance.skip_frames(count)
      end

      def self.hold(seconds : Float64) : VCR
        instance.hold(seconds)
      end

      def self.write_terminal(data : String, delay : Float64 = 0.0) : VCR
        instance.write_terminal(data, delay)
      end

      def self.type_text(text : String, cps : Float64 = 25.0) : VCR
        instance.type_text(text, cps: cps)
      end

      def self.pause : VCR
        instance.pause
      end

      def self.resume : VCR
        instance.resume
      end

      def self.stop : VCR
        instance.stop
      end

      def self.save(path : String? = nil) : Nil
        instance.save(path)
      end

      def self.load(path_or_content : String) : VCR
        instance.load(path_or_content)
      end

      def self.play(speed : Float64 = 1.0, loop : Bool = false, &block : UI::Buffer, Int32 -> Nil) : Nil
        instance.play(speed: speed, loop: loop, &block)
      end

      def self.next_frame : PlaybackFrame
        instance.next_frame
      end

      def self.prev_frame : PlaybackFrame
        instance.prev_frame
      end

      def self.goto_frame(index : Int32) : PlaybackFrame
        instance.goto_frame(index)
      end

      def self.seek(timestamp_seconds : Float64) : PlaybackFrame
        instance.seek(timestamp_seconds)
      end

      def self.rewind : PlaybackFrame
        instance.rewind
      end

      def self.recording? : Bool
        instance.recording?
      end

      def self.paused? : Bool
        instance.paused?
      end

      def self.playing? : Bool
        instance.playing?
      end

      def self.current_buffer : UI::Buffer
        instance.current_buffer
      end

      def self.total_frames : Int32
        instance.total_frames
      end

      def self.duration : Float64
        instance.duration
      end

      def self.render_frame(target : UI::Buffer, x : Int32 = 0, y : Int32 = 0, respect_overlays : Bool = false) : Nil
        instance.render_frame(target, x, y, respect_overlays)
      end

      # --- Instance Attributes & State Machine ---

      getter recorder : ScreenRecorder? = nil
      getter player : PlaybackEngine? = nil
      enum State
        Idle
        Recording
        Playing
        Paused
        Stopped
      end
      getter state : State = State::Idle

      def initialize
      end

      # --- Recording Methods ---

      # Starts recording to a destination .cast file
      def record(
        path : String,
        width : Int32 = 80,
        height : Int32 = 24,
        title : String = "Opal Session",
        term : String = "xterm-256color",
      ) : self
        rec = ScreenRecorder.new(path, width: width, height: height, title: title, term: term)
        rec.start
        @recorder = rec
        @state = State::Recording
        self
      end

      # Scoped block recording with automatic start, pacing, and save on exit
      def record(
        path : String,
        width : Int32 = 80,
        height : Int32 = 24,
        title : String = "Opal Session",
        term : String = "xterm-256color",
        &
      ) : self
        record(path, width: width, height: height, title: title, term: term)
        begin
          with self yield self
        ensure
          stop
          save(path)
        end
        self
      end

      # Captures a screen buffer snapshot onto the current recording tape
      def capture(buffer : UI::Buffer, advance : Float64? = nil) : Bool
        if rec = @recorder
          return false if @state == State::Paused
          rec.capture_frame(buffer, advance)
        else
          false
        end
      end

      # Advances the recording timeline by N simulated frame durations
      def wait_frames(count : Int32 = 1, delay_per_frame : Float64 = 0.05) : self
        @recorder.try(&.wait_frames(count, delay_per_frame))
        self
      end

      # Drops the next N frames from recording
      def skip_frames(count : Int32) : self
        @recorder.try(&.skip_frames(count))
        self
      end

      # Holds the current visual buffer for a specified duration in playback
      def hold(seconds : Float64) : self
        @recorder.try(&.hold(seconds))
        self
      end

      # Writes raw terminal output or control sequences directly to active recorder
      def write_terminal(data : String, delay : Float64 = 0.0) : self
        @recorder.try(&.write_terminal(data, delay))
        self
      end

      # Simulates human keystroke typing directly to active recorder
      def type_text(text : String, cps : Float64 = 25.0) : self
        @recorder.try(&.type_text(text, cps: cps))
        self
      end

      # Pauses active recording or playback
      def pause : self
        if @state == State::Recording
          @recorder.try(&.pause)
          @state = State::Paused
        elsif @state == State::Playing
          @player.try(&.pause)
          @state = State::Paused
        end
        self
      end

      # Resumes paused recording or playback
      def resume : self
        if @recorder && @recorder.not_nil!.active?
          @recorder.try(&.resume)
          @state = State::Recording
        elsif @player
          @player.try(&.resume)
          @state = State::Playing
        end
        self
      end

      # Stops recording or playback
      def stop : self
        if rec = @recorder
          rec.stop
        end
        if pl = @player
          pl.stop
        end
        @state = State::Stopped
        self
      end

      # Saves the current recording tape to disk
      def save(path : String? = nil) : Nil
        @recorder.try(&.save(path))
      end

      def recording? : Bool
        @state == State::Recording
      end

      def paused? : Bool
        @state == State::Paused
      end

      def playing? : Bool
        @state == State::Playing
      end

      def frame_count : Int32
        @recorder.try(&.frame_count) || 0
      end

      def elapsed : Float64
        @recorder.try(&.writer.elapsed) || 0.0_f64
      end

      # --- Playback Methods ---

      # Loads a recording file or raw content as a playback tape
      def load(path_or_content : String) : self
        @player = PlaybackEngine.from_file(path_or_content) rescue PlaybackEngine.from_string(path_or_content)
        @state = State::Idle
        self
      end

      # Loads an existing Reader::Recording directly
      def load(recording : Reader::Recording) : self
        @player = PlaybackEngine.new(recording)
        @state = State::Idle
        self
      end

      # Automated playback loop yielding each frame buffer and index
      def play(speed : Float64 = 1.0, loop : Bool = false, &block : UI::Buffer, Int32 -> Nil) : Nil
        if pl = @player
          @state = State::Playing
          pl.play(speed: speed, loop: loop, &block)
          @state = State::Stopped
        end
      end

      def next_frame : PlaybackFrame
        @player.try(&.next_frame) || PlaybackFrame.new(0, 0.0, UI::Buffer.new(80, 24))
      end

      def prev_frame : PlaybackFrame
        @player.try(&.prev_frame) || PlaybackFrame.new(0, 0.0, UI::Buffer.new(80, 24))
      end

      def goto_frame(index : Int32) : PlaybackFrame
        @player.try(&.goto_frame(index)) || PlaybackFrame.new(0, 0.0, UI::Buffer.new(80, 24))
      end

      def seek(timestamp_seconds : Float64) : PlaybackFrame
        @player.try(&.seek(timestamp_seconds)) || PlaybackFrame.new(0, 0.0, UI::Buffer.new(80, 24))
      end

      def rewind : PlaybackFrame
        @player.try(&.rewind) || PlaybackFrame.new(0, 0.0, UI::Buffer.new(80, 24))
      end

      def current_frame : PlaybackFrame
        @player.try(&.current_frame) || PlaybackFrame.new(0, 0.0, UI::Buffer.new(80, 24))
      end

      def current_buffer : UI::Buffer
        @player.try(&.current_buffer) || UI::Buffer.new(80, 24)
      end

      def current_timestamp : Float64
        @player.try(&.current_timestamp) || 0.0_f64
      end

      def current_frame_index : Int32
        @player.try(&.current_index) || 0
      end

      def total_frames : Int32
        @player.try(&.total_frames) || 0
      end

      def duration : Float64
        @player.try(&.duration) || 0.0_f64
      end

      def has_next? : Bool
        @player.try(&.has_next?) || false
      end

      def has_prev? : Bool
        @player.try(&.has_prev?) || false
      end

      # Attaches a persistent overlay onto playback
      def add_overlay(element : UI::Element, x : Int32, y : Int32, width : Int32, height : Int32) : self
        @player.try(&.add_overlay(element, x, y, width, height))
        self
      end

      def clear_overlays : self
        @player.try(&.clear_overlays)
        self
      end

      # Composites current playback frame into destination buffer, respecting existing overlays if requested
      def render_frame(
        target : UI::Buffer,
        x : Int32 = 0,
        y : Int32 = 0,
        respect_overlays : Bool = false,
      ) : Nil
        @player.try(&.render_frame(target, x, y, respect_overlays))
      end
    end
  end
end
