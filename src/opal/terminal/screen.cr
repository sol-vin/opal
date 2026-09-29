module Opal
  module Terminal
    # Screen control and ANSI terminal escape codes.
    module Screen
      ESC = "\e"
      CSI = "\e["

      # Screen buffer controls
      ENTER_ALT_BUFFER = "\e[?1049h"
      EXIT_ALT_BUFFER  = "\e[?1049l"

      # Cursor visibility
      HIDE_CURSOR = "\e[?25l"
      SHOW_CURSOR = "\e[?25h"

      # Mouse tracking (SGR mode 1006 with button event 1002 and normal tracking 1000)
      ENABLE_MOUSE  = "\e[?1000h\e[?1002h\e[?1006h"
      DISABLE_MOUSE = "\e[?1006l\e[?1002l\e[?1000l"

      # Clearing
      CLEAR_ALL        = "\e[2J"
      CLEAR_LINE       = "\e[2K"
      CLEAR_LINE_RIGHT = "\e[0K"
      CLEAR_LINE_LEFT  = "\e[1K"
      CLEAR_DOWN       = "\e[0J"
      CURSOR_HOME      = "\e[H"
      RESET_FORMAT     = "\e[0m"

      # Returns an escape code to position the cursor at (row, col) (1-indexed).
      def self.move_to(row : Int32, col : Int32) : String
        "\e[#{row};#{col}H"
      end

      # Returns an escape code to move the cursor up *n* lines.
      def self.move_up(n : Int32 = 1) : String
        n > 0 ? "\e[#{n}A" : ""
      end

      # Returns an escape code to move the cursor down *n* lines.
      def self.move_down(n : Int32 = 1) : String
        n > 0 ? "\e[#{n}B" : ""
      end

      # Returns an escape code to move the cursor forward *n* columns.
      def self.move_forward(n : Int32 = 1) : String
        n > 0 ? "\e[#{n}C" : ""
      end

      # Returns an escape code to move the cursor backward *n* columns.
      def self.move_backward(n : Int32 = 1) : String
        n > 0 ? "\e[#{n}D" : ""
      end

      # Returns an escape code to set the terminal window title.
      def self.set_title(title : String) : String
        "\e]0;#{title}\a"
      end
    end
  end
end
