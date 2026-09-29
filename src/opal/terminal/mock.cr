require "./driver"

module Opal
  module Terminal
    # In-memory mock terminal driver for headless automated testing.
    class MockDriver < Driver
      property width : Int32
      property height : Int32
      getter output_io : IO::Memory
      property event_queue : Array(KeyEvent | MouseEvent)
      getter? in_raw_mode : Bool = false
      getter? alt_screen : Bool = false
      getter? cursor_visible : Bool = true
      getter? mouse_enabled : Bool = false

      def initialize(@width = 80, @height = 24)
        @output_io = IO::Memory.new
        @event_queue = [] of (KeyEvent | MouseEvent)
      end

      def size : {Int32, Int32}
        {@width, @height}
      end

      def raw_mode(&)
        old_raw = @in_raw_mode
        @in_raw_mode = true
        begin
          yield
        ensure
          @in_raw_mode = old_raw
        end
      end

      def write(str : String) : Nil
        @output_io << str
      end

      def flush : Nil
        @output_io.flush
      end

      def read_event : KeyEvent | MouseEvent | Nil
        @event_queue.shift?
      end

      def enter_alternate_screen : Nil
        @alt_screen = true
        super
      end

      def exit_alternate_screen : Nil
        @alt_screen = false
        super
      end

      def hide_cursor : Nil
        @cursor_visible = false
        super
      end

      def show_cursor : Nil
        @cursor_visible = true
        super
      end

      def enable_mouse : Nil
        @mouse_enabled = true
        super
      end

      def disable_mouse : Nil
        @mouse_enabled = false
        super
      end

      # Injects a key event into the mock input stream
      def inject_key(name : String, char : Char? = nil, ctrl : Bool = false, alt : Bool = false, shift : Bool = false) : self
        @event_queue << KeyEvent.new(name, char, ctrl: ctrl, alt: alt, shift: shift)
        self
      end

      # Injects a mouse event
      def inject_mouse(x : Int32, y : Int32, button : MouseButton, action : MouseAction) : self
        @event_queue << MouseEvent.new(x, y, button, action)
        self
      end

      # Returns the full recorded output string
      def output : String
        @output_io.to_s
      end

      # Clears the recorded output buffer
      def clear_output : Nil
        @output_io.clear
      end

      # Returns the output with all ANSI escape sequences removed
      def stripped_output : String
        output.gsub(/\e\[[0-9;?]*[a-zA-Z]/, "").gsub(/\e\].*?\a/, "")
      end
    end
  end
end
