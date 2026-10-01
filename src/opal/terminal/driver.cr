require "./screen"
require "./ansi_parser"

module Opal
  module Terminal
    # Abstract base interface for terminal input/output drivers.
    abstract class Driver
      property output : IO
      property input : IO
      @buffered_events = Deque(KeyEvent | MouseEvent).new
      @input_buffer = Bytes.new(512)

      def initialize(@output : IO = STDOUT, @input : IO = STDIN)
      end

      abstract def size : {Int32, Int32}
      abstract def raw_mode(& : ->)
      abstract def write(str : String) : Nil
      abstract def flush : Nil

      # Reads the next key or mouse event from the terminal, consuming from the
      # internal event queue if multiple events arrived in the same read chunk.
      def read_event : KeyEvent | MouseEvent | Nil
        unless @buffered_events.empty?
          return @buffered_events.shift
        end

        bytes_read = begin
          @input.read(@input_buffer)
        rescue IO::Error
          0
        end

        return nil if bytes_read <= 0

        seq = String.new(@input_buffer[0, bytes_read])
        events = AnsiParser.parse_all(seq)
        return nil if events.empty?

        first = events.shift
        events.each { |ev| @buffered_events.push(ev) }
        first
      end

      def enter_alternate_screen : Nil
        write(Screen::ENTER_ALT_BUFFER)
        flush
      end

      def exit_alternate_screen : Nil
        write(Screen::EXIT_ALT_BUFFER)
        flush
      end

      def hide_cursor : Nil
        write(Screen::HIDE_CURSOR)
        flush
      end

      def show_cursor : Nil
        write(Screen::SHOW_CURSOR)
        flush
      end

      def enable_mouse : Nil
        write(Screen::ENABLE_MOUSE)
        flush
      end

      def disable_mouse : Nil
        write(Screen::DISABLE_MOUSE)
        flush
      end

      def clear : Nil
        write(Screen::CLEAR_ALL + Screen::CURSOR_HOME)
        flush
      end

      def move_to(row : Int32, col : Int32) : Nil
        write(Screen.move_to(row, col))
      end
    end
  end
end
