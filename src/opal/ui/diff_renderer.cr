require "./buffer"
require "../terminal"

module Opal
  module UI
    # High-performance double-buffered differential terminal renderer.
    # Emits minimal ANSI escape sequences by diffing the current frame against the previous frame.
    class DiffRenderer
      property driver : Terminal::Driver
      @previous_buffer : Buffer? = nil

      def initialize(driver : Terminal::Driver? = nil)
        @driver = driver || Terminal.default_driver
      end

      # Renders a buffer frame using differential cell comparisons.
      def render(buffer : Buffer) : Nil
        prev = @previous_buffer

        # If first render or dimensions resized, do a full redraw
        if prev.nil? || prev.width != buffer.width || prev.height != buffer.height
          full_render(buffer)
          @previous_buffer = buffer.clone
          return
        end

        io = IO::Memory.new
        last_fg = Color.none
        last_bg = Color.none
        last_bold = false
        last_dim = false
        last_italic = false
        last_underline = false
        cursor_x = -1
        cursor_y = -1

        (0...buffer.height).each do |y|
          (0...buffer.width).each do |x|
            curr_cell = buffer.get(x, y)
            prev_cell = prev.get(x, y)

            # Skip unchanged cells!
            next if curr_cell == prev_cell

            # Position cursor if not already at cell
            if cursor_x != x || cursor_y != y
              io << "\e[#{y + 1};#{x + 1}H"
              cursor_x = x
              cursor_y = y
            end

            # Update styling if changed
            if curr_cell.bold? != last_bold ||
               curr_cell.dim? != last_dim ||
               curr_cell.italic? != last_italic ||
               curr_cell.underline? != last_underline ||
               curr_cell.fg != last_fg ||
               curr_cell.bg != last_bg
              io << "\e[0m" # Reset
              last_bold = curr_cell.bold?
              last_dim = curr_cell.dim?
              last_italic = curr_cell.italic?
              last_underline = curr_cell.underline?
              last_fg = curr_cell.fg
              last_bg = curr_cell.bg

              codes = [] of String
              codes << "1" if last_bold
              codes << "2" if last_dim
              codes << "3" if last_italic
              codes << "4" if last_underline
              io << "\e[" + codes.join(';') + "m" unless codes.empty?
              io << last_fg.fg_escape
              io << last_bg.bg_escape
            end

            # Write character
            io << curr_cell.char
            cursor_x += 1
          end
        end

        # Reset terminal format if any changes were written
        if io.bytesize > 0
          io << "\e[0m"
          @driver.write(io.to_s)
          @driver.flush
        end

        @previous_buffer = buffer.clone
      end

      private def full_render(buffer : Buffer) : Nil
        io = IO::Memory.new
        io << Terminal::Screen::CURSOR_HOME

        (0...buffer.height).each do |y|
          io << "\e[#{y + 1};1H"
          (0...buffer.width).each do |x|
            cell = buffer.get(x, y)
            io << cell.fg.fg_escape
            io << cell.bg.bg_escape
            io << "\e[1m" if cell.bold?
            io << "\e[2m" if cell.dim?
            io << cell.char
            io << "\e[0m"
          end
        end

        @driver.write(io.to_s)
        @driver.flush
      end
    end
  end
end
