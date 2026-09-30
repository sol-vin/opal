require "json"
require "./header"
require "./event"

module Opal
  module Asciicast
    # Parses Asciinema v2 format streams or files into structured recordings.
    class Reader
      record Recording,
        header : Header,
        events : Array(Event) do
        # Returns the total duration of the recording in seconds
        def duration : Float64
          events.empty? ? 0.0_f64 : events.last.time
        end

        # Returns all terminal output events
        def outputs : Array(Event)
          events.select(&.output?)
        end

        # Returns all terminal input events
        def inputs : Array(Event)
          events.select(&.input?)
        end

        # Returns all marker events
        def markers : Array(Event)
          events.select(&.marker?)
        end

        # Returns the concatenated text emitted across all output events
        def total_output_text : String
          io = IO::Memory.new
          outputs.each { |ev| io << ev.data }
          io.to_s
        end
      end

      # Reads an asciicast from a file path
      def self.from_file(path : String) : Recording
        File.open(path, "r") do |f|
          from_io(f)
        end
      end

      # Reads an asciicast from a raw string
      def self.from_string(content : String) : Recording
        from_io(IO::Memory.new(content))
      end

      # Reads an asciicast from an IO stream
      def self.from_io(io : IO) : Recording
        header_line = io.gets
        raise ArgumentError.new("Empty asciicast stream") unless header_line

        header = Header.from_json(header_line)
        events = [] of Event

        while line = io.gets
          trimmed = line.strip
          next if trimmed.empty?
          events << Event.from_json(trimmed)
        end

        Recording.new(header, events)
      end
    end
  end
end
