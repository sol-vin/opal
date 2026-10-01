require "../terminal/driver"
require "./writer"

module Opal
  module Asciicast
    # Headless terminal driver that records all screen output directly into
    # an Asciinema v2 recording (.cast) stream.
    # Allows any Opal application, TEA program, form wizard, or interactive UI
    # to be driven and recorded headlessly.
    class Driver < Terminal::Driver
      getter writer : Writer
      property time_advance : Float64
      property event_queue : Array(Terminal::KeyEvent | Terminal::MouseEvent)
      getter? in_raw_mode : Bool = false

      def initialize(
        width : Int32 = 80,
        height : Int32 = 24,
        title : String = "Opal Session",
        writer : Writer? = nil,
        @time_advance : Float64 = 0.05,
      )
        super()
        @writer = writer || Writer.new(width: width, height: height, title: title)
        @event_queue = [] of (Terminal::KeyEvent | Terminal::MouseEvent)
      end

      # Terminal dimensions from writer header
      def size : {Int32, Int32}
        {@writer.width, @writer.height}
      end

      # Simulates entering raw mode
      def raw_mode(&)
        old_raw = @in_raw_mode
        @in_raw_mode = true
        begin
          yield
        ensure
          @in_raw_mode = old_raw
        end
      end

      # Records an output chunk to the asciicast timeline
      def write(str : String) : Nil
        @writer.write(str, advance: @time_advance)
      end

      def flush : Nil
        # In-memory buffer flush (no-op)
      end

      # Reads the next simulated or injected input event
      def read_event : Terminal::KeyEvent | Terminal::MouseEvent | Nil
        @event_queue.shift?
      end

      # Injects a keyboard or mouse event into the driver's input stream
      def inject_event(event : Terminal::KeyEvent | Terminal::MouseEvent) : self
        @event_queue << event
        self
      end

      # Convenience helper: injects a keyboard event
      def inject_key(name : String, char : Char? = nil, ctrl : Bool = false, alt : Bool = false, shift : Bool = false) : self
        @event_queue << Terminal::KeyEvent.new(name, char, ctrl: ctrl, alt: alt, shift: shift)
        self
      end

      # Convenience helper: injects a mouse event
      def inject_mouse(
        x : Int32,
        y : Int32,
        button : Terminal::MouseButton = Terminal::MouseButton::Left,
        action : Terminal::MouseAction = Terminal::MouseAction::Press,
      ) : self
        @event_queue << Terminal::MouseEvent.new(x, y, button, action)
        self
      end

      # Pauses recording timeline
      def pause(seconds : Float64) : self
        @writer.pause(seconds)
        self
      end

      # Saves the recorded session to a .cast file
      def save(filename : String) : Nil
        @writer.save(filename)
      end

      # Returns the complete recorded asciicast content
      def to_s(io : IO) : Nil
        @writer.to_s(io)
      end

      def to_s : String
        @writer.to_s
      end
    end
  end
end
