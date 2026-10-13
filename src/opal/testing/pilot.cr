require "../terminal"
require "../terminal/mock"
require "../ui/engine"
require "../ui/control"
require "../ui/screen"
require "../ui/screen_stack"
require "../tea/program"

module Opal
  module Testing
    class TimeoutError < Exception
    end

    # Python Textual-inspired Pilot test harness.
    # Programmatically simulates user interactions (keystrokes, mouse gestures, resize events)
    # against interactive TUI applications, screen hierarchies, and control engines.
    class Pilot
      getter driver : Terminal::MockDriver
      property engine : UI::Engine?
      property screen_stack : UI::ScreenStack?
      property program : TEA::Program?

      def initialize(
        @driver : Terminal::MockDriver = Terminal::MockDriver.new(80, 24),
        @engine : UI::Engine? = nil,
        @screen_stack : UI::ScreenStack? = nil,
        @program : TEA::Program? = nil,
      )
      end

      # Factory method to create a Pilot for an Engine
      def self.for(engine : UI::Engine, driver : Terminal::MockDriver = Terminal::MockDriver.new(80, 24)) : self
        new(driver: driver, engine: engine)
      end

      # Factory method to create a Pilot for a Screen or ScreenStack
      def self.for(screen : UI::Screen, driver : Terminal::MockDriver = Terminal::MockDriver.new(80, 24)) : self
        stack = UI::ScreenStack.new(screen)
        new(driver: driver, screen_stack: stack)
      end

      # Factory method to create a Pilot for a ScreenStack
      def self.for(stack : UI::ScreenStack, driver : Terminal::MockDriver = Terminal::MockDriver.new(80, 24)) : self
        new(driver: driver, screen_stack: stack)
      end

      # Factory method to create a Pilot for a TEA Program
      def self.for(prog : TEA::Program, driver : Terminal::MockDriver) : self
        new(driver: driver, program: prog)
      end

      # Simulates pressing one or more keys in sequential order.
      # Automatically resolves special key representations ("tab", "shift+tab", "enter", "esc", "ctrl+c", etc.).
      def press(*keys : String) : self
        keys.each do |k|
          event = parse_key_string(k)
          dispatch_key(event)
        end
        Fiber.yield
        self
      end

      # Types a string character-by-character as synthetic key events.
      def type(text : String) : self
        text.each_char do |ch|
          event = Terminal::KeyEvent.new(ch.to_s, ch)
          dispatch_key(event)
        end
        Fiber.yield
        self
      end

      # Simulates a mouse click at the given terminal coordinates.
      def click(
        x : Int32,
        y : Int32,
        button : Terminal::MouseButton = Terminal::MouseButton::Left,
      ) : self
        press_ev = Terminal::MouseEvent.new(x, y, button, Terminal::MouseAction::Press)
        release_ev = Terminal::MouseEvent.new(x, y, button, Terminal::MouseAction::Release)
        dispatch_mouse(press_ev)
        dispatch_mouse(release_ev)
        Fiber.yield
        self
      end

      # Simulates clicking on a managed UI control.
      def click(control : UI::Control) : self
        if eng = @engine
          eng.focus(control)
        end
        click(0, 0)
      end

      # Simulates mouse hover over the given terminal coordinates.
      def hover(x : Int32, y : Int32) : self
        move_ev = Terminal::MouseEvent.new(x, y, Terminal::MouseButton::None, Terminal::MouseAction::Motion)
        dispatch_mouse(move_ev)
        Fiber.yield
        self
      end

      # Simulates mouse scroll wheel movements.
      def scroll_up(x : Int32 = 0, y : Int32 = 0) : self
        ev = Terminal::MouseEvent.new(x, y, Terminal::MouseButton::WheelUp, Terminal::MouseAction::Press)
        dispatch_mouse(ev)
        Fiber.yield
        self
      end

      def scroll_down(x : Int32 = 0, y : Int32 = 0) : self
        ev = Terminal::MouseEvent.new(x, y, Terminal::MouseButton::WheelDown, Terminal::MouseAction::Press)
        dispatch_mouse(ev)
        Fiber.yield
        self
      end

      # Resizes the mock terminal and dispatches resize events.
      def resize_terminal(width : Int32, height : Int32) : self
        @driver.inject_resize(width, height)
        if stack = @screen_stack
          stack.active_screen.try(&.on_resize(width, height))
        end
        Fiber.yield
        self
      end

      # Yields execution to let pending background fibers, timers, or animations settle.
      def pause(duration : Time::Span = 5.milliseconds) : self
        sleep duration
        Fiber.yield
        self
      end

      # Waits until the condition block evaluates to true, raising TimeoutError if duration exceeded.
      def wait_for(
        timeout : Time::Span = 1.second,
        interval : Time::Span = 5.milliseconds,
        message : String = "Condition timed out waiting for Pilot assertion",
        &block : -> Bool
      ) : self
        start = Time.instant
        while (Time.instant - start) < timeout
          return self if block.call
          sleep interval
          Fiber.yield
        end

        raise TimeoutError.new("#{message} after #{timeout.total_milliseconds}ms")
      end

      # Drains any pending event queue in the mock driver.
      def wait_for_idle : self
        loop do
          event = @driver.poll_event(0)
          break unless event
          dispatch_event(event)
        end
        Fiber.yield
        self
      end

      private def dispatch_event(event : Terminal::KeyEvent | Terminal::MouseEvent | Terminal::ResizeEvent) : Nil
        case event
        when Terminal::KeyEvent
          dispatch_key(event)
        when Terminal::MouseEvent
          dispatch_mouse(event)
        when Terminal::ResizeEvent
          resize_terminal(event.width, event.height)
        end
      end

      private def dispatch_key(event : Terminal::KeyEvent) : Nil
        if eng = @engine
          eng.handle_key(event)
        elsif stack = @screen_stack
          stack.active_screen.try(&.handle_key(event))
        else
          @driver.event_queue << event
        end
      end

      private def dispatch_mouse(event : Terminal::MouseEvent) : Nil
        if eng = @engine
          eng.handle_mouse(event)
        elsif stack = @screen_stack
          stack.active_screen.try(&.handle_mouse(event))
        else
          @driver.event_queue << event
        end
      end

      private def parse_key_string(k : String) : Terminal::KeyEvent
        lower = k.downcase
        case lower
        when "tab"
          Terminal::KeyEvent.new("tab", '\t')
        when "shift+tab", "backtab"
          Terminal::KeyEvent.new("shift+tab", '\t', shift: true)
        when "enter", "return"
          Terminal::KeyEvent.new("enter", '\r')
        when "esc", "escape"
          Terminal::KeyEvent.new("escape", '\e')
        when "space"
          Terminal::KeyEvent.new("space", ' ')
        when "backspace"
          Terminal::KeyEvent.new("backspace", '\b')
        when "up", "down", "left", "right"
          Terminal::KeyEvent.new(lower)
        when /^ctrl\+([a-z0-9])$/
          char_val = $1[0]
          Terminal::KeyEvent.new(lower, char_val, ctrl: true)
        when /^alt\+([a-z0-9])$/
          char_val = $1[0]
          Terminal::KeyEvent.new(lower, char_val, alt: true)
        when /^shift\+([a-z0-9])$/
          char_val = $1[0].upcase
          Terminal::KeyEvent.new(lower, char_val, shift: true)
        else
          if k.size == 1
            Terminal::KeyEvent.new(k, k[0])
          else
            Terminal::KeyEvent.new(k)
          end
        end
      end
    end
  end
end
