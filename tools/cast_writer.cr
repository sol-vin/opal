require "json"

module Opal
  module Tools
    # Generates standard Asciinema v2 format recordings (.cast).
    # Spec: https://github.com/asciinema/asciinema/blob/develop/doc/asciicast-v2.md
    class CastWriter
      getter width : Int32
      getter height : Int32
      getter title : String

      def initialize(
        @width : Int32 = 80,
        @height : Int32 = 24,
        @title : String = "Opal Demo",
      )
        @elapsed = 0.0_f64
        @lines = [] of String

        # Line 1: Header object
        header = {
          "version"   => 2,
          "width"     => @width,
          "height"    => @height,
          "timestamp" => Time.utc.to_unix,
          "title"     => @title,
          "env"       => {
            "TERM"  => "xterm-256color",
            "SHELL" => "/bin/bash",
          },
        }
        @lines << header.to_json
      end

      # Writes an output event [time, "o", data] with a time advance
      def write(data : String, advance : Float64 = 0.05) : Nil
        @elapsed += advance
        event = [@elapsed.round(3), "o", data]
        @lines << event.to_json
      end

      # Simulates human typing cadence for a string
      def type_text(text : String, cps : Float64 = 16.0) : Nil
        delay_per_char = 1.0 / cps
        text.each_char do |ch|
          # Slight randomized variation around typing speed
          jitter = (rand * 0.02) - 0.01
          actual_delay = Math.max(0.015, delay_per_char + jitter)
          write(ch.to_s, actual_delay)
        end
      end

      # Pauses playback
      def pause(seconds : Float64) : Nil
        @elapsed += seconds
      end

      # Clears the terminal screen and homes the cursor
      def clear_screen(advance : Float64 = 0.02) : Nil
        write("\e[2J\e[H", advance)
      end

      # Moves cursor to row, col
      def move_to(row : Int32, col : Int32, advance : Float64 = 0.01) : Nil
        write("\e[#{row};#{col}H", advance)
      end

      # Saves the asciicast file (UTF-8 without BOM)
      def save(filename : String) : Nil
        # Ensure parent directory exists
        dir = File.dirname(filename)
        Dir.mkdir_p(dir) unless Dir.exists?(dir)

        File.open(filename, "w") do |f|
          @lines.each do |line|
            f.puts(line)
          end
        end
      end
    end
  end
end
