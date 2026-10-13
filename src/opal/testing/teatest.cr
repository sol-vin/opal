require "../tea"
require "../terminal/mock"

module Opal
  module Testing
    # Charmbracelet Bubbletea-inspired TestProgram test harness.
    # Wraps a TEA Model/Program running concurrently, enabling programmatic key typing,
    # concurrent message injection (send), output assertion, and graceful termination waiting.
    class TestProgram
      getter program : TEA::Program
      getter driver : Terminal::MockDriver
      getter? finished : Bool = false
      getter final_model : TEA::Model? = nil
      getter error : Exception? = nil
      @done_channel : Channel(TEA::Model)

      def initialize(
        model : TEA::Model,
        width : Int32 = 80,
        height : Int32 = 24,
        alt_screen : Bool = false,
        mouse_enabled : Bool = false,
        diff_render : Bool = false,
      )
        @driver = Terminal::MockDriver.new(width, height)
        @program = TEA::Program.new(
          model,
          driver: @driver,
          alt_screen: alt_screen,
          mouse_enabled: mouse_enabled,
          diff_render: diff_render,
        )
        @done_channel = Channel(TEA::Model).new(1)
        start_fiber
      end

      # Factory constructor
      def self.new(
        model : TEA::Model,
        width : Int32 = 80,
        height : Int32 = 24,
        alt_screen : Bool = false,
        mouse_enabled : Bool = false,
        diff_render : Bool = false,
      ) : self
        allocate.tap(&.initialize(model, width, height, alt_screen, mouse_enabled, diff_render))
      end

      # Simulates typing text into the program's input stream.
      def type(text : String) : self
        text.each_char do |ch|
          @driver.inject_key(ch.to_s, ch)
        end
        Fiber.yield
        self
      end

      # Dispatches a single key into the program's input stream.
      def key(name : String, char : Char? = nil, ctrl : Bool = false, alt : Bool = false, shift : Bool = false) : self
        @driver.inject_key(name, char, ctrl: ctrl, alt: alt, shift: shift)
        Fiber.yield
        self
      end

      # Sends a message directly into the active application event loop (matching Bubbletea p.Send).
      def send(msg : TEA::Msg) : self
        @program.send(msg)
        Fiber.yield
        self
      end

      # Programmatically requests program exit.
      def quit : self
        @program.quit
        Fiber.yield
        self
      end

      # Returns the recorded output stripped of ANSI escapes.
      def output : String
        @driver.stripped_output
      end

      # Returns the raw recorded output with ANSI escapes preserved.
      def raw_output : String
        @driver.output
      end

      # Waits until output matches the condition block within the specified timeout.
      def wait_for(
        timeout : Time::Span = 1.second,
        interval : Time::Span = 5.milliseconds,
        message : String = "Condition timed out waiting for output assertion",
        &block : String -> Bool
      ) : self
        start = Time.instant
        while (Time.instant - start) < timeout

          return self if block.call(output)
          sleep interval
          Fiber.yield
        end

        raise TimeoutError.new("#{message} after #{timeout.total_milliseconds}ms. Current output:\n#{output}")
      end

      # Waits for the TEA program to exit cleanly and returns the final Model state.
      def wait_finished(timeout : Time::Span = 2.seconds) : TEA::Model
        if @finished
          if ex = @error
            raise ex
          end
          return @final_model.not_nil!
        end

        select
        when model = @done_channel.receive
          @finished = true
          @final_model = model
          model
        when timeout(timeout)
          raise TimeoutError.new("TestProgram failed to finish within #{timeout.total_milliseconds}ms")
        end
      end

      private def start_fiber : Nil
        spawn do
          begin
            res = @program.run
            @finished = true
            @final_model = res
            @done_channel.send(res)
          rescue ex : Exception
            @error = ex
            @finished = true
          end
        end
        # Allow program init and initial render to complete
        Fiber.yield
      end
    end
  end
end
