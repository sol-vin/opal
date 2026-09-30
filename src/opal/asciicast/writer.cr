require "json"
require "./header"
require "./event"
require "../ui/buffer"

module Opal
  module Asciicast
    # Generates standard Asciinema v2 format recordings (.cast).
    # Spec: https://github.com/asciinema/asciinema/blob/develop/doc/asciicast-v2.md
    class Writer
      getter header : Header
      getter events : Array(Event)
      getter elapsed : Float64

      def initialize(
        width : Int32 = 80,
        height : Int32 = 24,
        title : String = "Opal Demo",
        term : String = "xterm-256color",
        shell : String = "/bin/bash",
        theme : Hash(String, String)? = nil,
        idle_time_limit : Float64? = nil,
      )
        @header = Header.new(
          width: width,
          height: height,
          title: title,
          timestamp: Time.utc.to_unix,
          term: term,
          shell: shell,
          theme: theme,
          idle_time_limit: idle_time_limit
        )
        @events = [] of Event
        @elapsed = 0.0_f64
      end

      def width : Int32
        @header.width
      end

      def height : Int32
        @header.height
      end

      def title : String
        @header.title || ""
      end

      # Writes an output event [time, "o", data] with a time advance
      def write(data : String, advance : Float64 = 0.05) : Nil
        @elapsed += advance
        @events << Event.output(@elapsed, data)
      end

      # Writes an input event [time, "i", data]
      def write_input(data : String, advance : Float64 = 0.0) : Nil
        @elapsed += advance
        @events << Event.input(@elapsed, data)
      end

      # Writes a marker event [time, "m", label]
      def write_marker(label : String, advance : Float64 = 0.0) : Nil
        @elapsed += advance
        @events << Event.marker(@elapsed, label)
      end

      # Simulates human typing cadence for a string
      def type_text(text : String, cps : Float64 = 16.0, jitter : Float64 = 0.02) : Nil
        delay_per_char = 1.0 / cps
        text.each_char do |ch|
          # Slight randomized variation around typing speed
          var = (rand * (jitter * 2.0)) - jitter
          actual_delay = Math.max(0.015, delay_per_char + var)
          write(ch.to_s, actual_delay)
        end
      end

      # Pauses playback by advancing elapsed time
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
      # ensuring flicker-free terminal updates with full ANSI color styling.
      def draw_buffer(buf : UI::Buffer, advance : Float64 = 0.05) : Nil
        io = IO::Memory.new
        io << "\e[H" # cursor home (1,1)

        (0...buf.height).each do |y|
          io << "\e[#{y + 1};1H" # position at start of row
          last_fg = Color.none
          last_bg = Color.none
          last_bold = false
          last_dim = false
          last_italic = false
          last_underline = false
          last_reverse = false

          (0...buf.width).each do |x|
            cell = buf.get(x, y)
            next if cell.continuation?

            style_changed = cell.bold? != last_bold ||
                            cell.dim? != last_dim ||
                            cell.italic? != last_italic ||
                            cell.underline? != last_underline ||
                            cell.reverse? != last_reverse ||
                            cell.fg != last_fg ||
                            cell.bg != last_bg

            if style_changed
              io << "\e[0m"
              io << "\e[1m" if cell.bold?
              io << "\e[2m" if cell.dim?
              io << "\e[3m" if cell.italic?
              io << "\e[4m" if cell.underline?
              io << "\e[7m" if cell.reverse?
              io << cell.fg.fg_escape
              io << cell.bg.bg_escape

              last_bold = cell.bold?
              last_dim = cell.dim?
              last_italic = cell.italic?
              last_underline = cell.underline?
              last_reverse = cell.reverse?
              last_fg = cell.fg
              last_bg = cell.bg
            end

            io << cell.char
          end
          io << "\e[0m"
        end

        write(io.to_s, advance)
      end

      # Generates the complete .cast file contents as a string
      def to_s(io : IO) : Nil
        io << @header.to_json << "\n"
        @events.each do |ev|
          ev.to_s(io)
          io << "\n"
        end

        # Ensure final frame hold is recorded if elapsed > last event time
        if !@events.empty? && @elapsed > @events.last.time
          hold_ev = Event.output(@elapsed, "")
          hold_ev.to_s(io)
          io << "\n"
        end
      end

      # Saves the asciicast file (UTF-8 without BOM)
      def save(filename : String) : Nil
        dir = File.dirname(filename)
        Dir.mkdir_p(dir) unless Dir.exists?(dir)

        File.open(filename, "w") do |f|
          to_s(f)
        end
      end
    end
  end
end
