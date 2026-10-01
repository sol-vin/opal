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

      # Invalidates the previous buffer cache, forcing the next render frame
      # to perform a complete full-screen redraw with line clearing.
      def invalidate! : Nil
        @previous_buffer = nil
      end

      # Renders a buffer frame using differential cell comparisons.
      def render(buffer : Buffer) : Nil
        prev = @previous_buffer

        # If first render or dimensions resized, do a full redraw
        if prev.nil? || prev.width != buffer.width || prev.height != buffer.height
          full_render(buffer, is_resize: !prev.nil?)
          if prev && prev.width == buffer.width && prev.height == buffer.height
            prev.copy_from(buffer)
          else
            @previous_buffer = buffer.clone
          end
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

            # Skip continuation cells
            next if curr_cell.continuation?

            # Skip unchanged cells!
            next if curr_cell == prev_cell

            # Position cursor if not already at cell
            if cursor_x != x || cursor_y != y
              io << "\e["
              (y + 1).to_s(io)
              io << ';'
              (x + 1).to_s(io)
              io << 'H'
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

              io << "\e[1m" if last_bold
              io << "\e[2m" if last_dim
              io << "\e[3m" if last_italic
              io << "\e[4m" if last_underline
              last_fg.write_fg_escape(io)
              last_bg.write_bg_escape(io)
            end

            # Write character
            io << curr_cell.char
            cw = VisualWidth.char_width(curr_cell.char)
            cursor_x += (cw > 0 ? cw : 1)
          end
        end

        # Reset terminal format if any changes were written
        if io.bytesize > 0
          io << "\e[0m"
          @driver.write(io.to_s)
          @driver.flush
        end

        prev.copy_from(buffer)
      end

      private def full_render(buffer : Buffer, is_resize : Bool = false) : Nil
        io = IO::Memory.new
        io << Terminal::Screen::CURSOR_HOME

        (0...buffer.height).each do |y|
          io << "\e["
          (y + 1).to_s(io)
          io << ";1H"
          last_fg = Color.none
          last_bg = Color.none
          last_bold = false
          last_dim = false

          (0...buffer.width).each do |x|
            cell = buffer.get(x, y)
            next if cell.continuation?

            if cell.bold? != last_bold || cell.dim? != last_dim || cell.fg != last_fg || cell.bg != last_bg
              io << "\e[0m"
              io << "\e[1m" if cell.bold?
              io << "\e[2m" if cell.dim?
              cell.fg.write_fg_escape(io)
              cell.bg.write_bg_escape(io)
              last_bold = cell.bold?
              last_dim = cell.dim?
              last_fg = cell.fg
              last_bg = cell.bg
            end
            io << cell.char
          end
          io << "\e[0m\e[K"
        end

        io << "\e[J"
        @driver.write(io.to_s)
        @driver.flush
      end
    end
  end
end
