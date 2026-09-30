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

      # Draws a full Buffer into the cast without clearing the screen,
      # ensuring rock-solid, flicker-free terminal updates with full ANSI color.
      def draw_buffer(buf : UI::Buffer, advance : Float64 = 0.05) : Nil
        io = IO::Memory.new
        io << "\e[H" # cursor home (1,1)
        (0...buf.height).each do |y|
          io << "\e[#{y + 1};1H" # position at start of row
          last_fg = Color.none
          last_bg = Color.none
          last_bold = false
          last_dim = false

          (0...buf.width).each do |x|
            cell = buf.get(x, y)
            next if cell.continuation?

            if cell.bold? != last_bold || cell.dim? != last_dim || cell.fg != last_fg || cell.bg != last_bg
              io << "\e[0m"
              io << "\e[1m" if cell.bold?
              io << "\e[2m" if cell.dim?
              io << cell.fg.fg_escape
              io << cell.bg.bg_escape
              last_bold = cell.bold?
              last_dim = cell.dim?
              last_fg = cell.fg
              last_bg = cell.bg
            end
            io << cell.char
          end
          io << "\e[0m"
        end
        write(io.to_s, advance)
      end

      # Saves the asciicast file (UTF-8 without BOM)
      def save(filename : String) : Nil
        # Ensure final frame hold is recorded in event timeline
        if @lines.size > 1
          # Record hold event at final elapsed timestamp
          event = [@elapsed.round(3), "o", ""]
          @lines << event.to_json
        end

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
