require "./driver"
require "./raw_mode"

module Opal
  module Terminal
    # POSIX (Linux/macOS) terminal driver using termios and ioctl.
    class PosixDriver < Driver
      {% unless flag?(:windows) %}
        lib LibC
          TIOCGWINSZ = 0x5413_u64 # Standard Linux TIOCGWINSZ, Darwin uses 0x40087468_u64

          struct Winsize
            ws_row : UInt16
            ws_col : UInt16
            ws_xpixel : UInt16
            ws_ypixel : UInt16
          end

          fun ioctl(fd : Int32, request : UInt64, arg : Winsize*) : Int32
        end
      {% end %}

      @input_buffer = Bytes.new(256)

      def size : {Int32, Int32}
        {% unless flag?(:windows) %}
          ws = LibC::Winsize.new
          # Try STDOUT fd = 1
          if LibC.ioctl(1, LibC::TIOCGWINSZ, pointerof(ws)) == 0 && ws.ws_col > 0 && ws.ws_row > 0
            return {ws.ws_col.to_i, ws.ws_row.to_i}
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
