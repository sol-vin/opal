require "../ui/buffer"
require "../terminal/mock"

module Opal
  module Testing
    # React Ink-inspired discrete frame history recorder.
    # Records successive rendered frames over time, allowing tests to verify
    # transition sequences, loading animations, and frame-by-frame UI diffs.
    class FrameRecorder
      getter frames : Array(String)
      getter buffers : Array(UI::Buffer)

      def initialize
        @frames = [] of String
        @buffers = [] of UI::Buffer
      end

      # Records a snapshot of the current UI::Buffer.
      def record(buffer : UI::Buffer) : self
        @buffers << buffer.clone
        @frames << buffer.screenshot(format: :text)
        self
      end

      # Records a plain text or ANSI frame string.
      def record(text : String) : self
        @frames << text
        self
      end

      # Returns the most recently recorded frame string, or empty string if none.
      def last_frame : String
        @frames.last? || ""
      end

      # Returns the most recently recorded buffer, or nil if none.
      def last_buffer : UI::Buffer?
        @buffers.last?
      end

      # Returns the number of recorded frames.
      def size : Int32
        @frames.size
      end

      # Returns true if no frames have been recorded.
      def empty? : Bool
        @frames.empty?
      end

      # Clears all recorded history.
      def clear : self
        @frames.clear
        @buffers.clear
        self
      end
    end
  end
end
