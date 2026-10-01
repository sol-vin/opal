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

      def initialize(output : IO = STDOUT, input : IO = STDIN)
        super(output, input)
      end

      def raw_mode(&)
        RawMode.run do
          yield
        end
      end

      def write(str : String) : Nil
        @output.print str
      rescue IO::Error
        # Handle broken pipes gracefully when output is piped to tools like head/fzf
      end

      def flush : Nil
        @output.flush
      rescue IO::Error
        # Handle broken pipes on flush
      end
    end
  end
end
