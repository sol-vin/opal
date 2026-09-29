require "./driver"
require "./raw_mode"

{% if flag?(:windows) %}
  lib LibC
    struct COORD
      x : Int16
      y : Int16
    end

    struct SMALL_RECT
      left : Int16
      top : Int16
      right : Int16
      bottom : Int16
    end

    struct CONSOLE_SCREEN_BUFFER_INFO
      dwSize : COORD
      dwCursorPosition : COORD
      wAttributes : UInt16
      srWindow : SMALL_RECT
      dwMaximumWindowSize : COORD
    end

    fun GetConsoleScreenBufferInfo(hConsoleOutput : HANDLE, lpConsoleScreenBufferInfo : CONSOLE_SCREEN_BUFFER_INFO*) : Int32
  end
{% end %}

module Opal
  module Terminal
    # Windows native terminal driver using Win32 Console API & VT100 sequences.
    class WindowsDriver < Driver
      @input_buffer = Bytes.new(256)

      def size : {Int32, Int32}
        {% if flag?(:windows) %}
          handle = LibC.GetStdHandle(LibC::STD_OUTPUT_HANDLE)
          if LibC.GetConsoleScreenBufferInfo(handle, out info) != 0
            cols = (info.srWindow.right - info.srWindow.left + 1).to_i
            rows = (info.srWindow.bottom - info.srWindow.top + 1).to_i
            return {cols > 0 ? cols : 80, rows > 0 ? rows : 24}
          end
        {% end %}

        cols = ENV["COLUMNS"]?.try(&.to_i?) || 80
        rows = ENV["LINES"]?.try(&.to_i?) || 24
        {cols, rows}
      end

      def raw_mode(&)
        RawMode.run do
          yield
        end
      end

      def write(str : String) : Nil
        STDOUT.print str
      end

      def flush : Nil
        STDOUT.flush
      end

      def read_event : KeyEvent | MouseEvent | Nil
        bytes_read = STDIN.read(@input_buffer)
        return nil if bytes_read <= 0

        seq = String.new(@input_buffer[0, bytes_read])
        if seq.starts_with?("\e[<")
          AnsiParser.parse_mouse(seq)
        else
          AnsiParser.parse_key(seq)
        end
      end
    end
  end
end
