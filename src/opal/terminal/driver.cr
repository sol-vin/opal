require "./screen"
require "./ansi_parser"

module Opal
  module Terminal
    # Abstract base interface for terminal input/output drivers.
    abstract class Driver
      abstract def size : {Int32, Int32}
      abstract def raw_mode(& : ->)
      abstract def write(str : String) : Nil
      abstract def flush : Nil
      abstract def read_event : KeyEvent | MouseEvent | Nil

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
