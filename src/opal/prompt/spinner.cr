require "../style"
require "../terminal"

module Opal
  module Prompt
    # Animated terminal spinner running asynchronously on a background Fiber.
    class Spinner
      FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

      property text : String
      @running : Bool = false
      @frame_idx : Int32 = 0
      @driver : Terminal::Driver

      def initialize(@text : String, driver : Terminal::Driver? = nil)
        @driver = driver || Terminal.default_driver
      end

      # Runs a block with an active spinner, automatically stopping when complete.
      def self.start(text : String, driver : Terminal::Driver? = nil, &block : Spinner -> T) : T forall T
        sp = new(text, driver)
        sp.start
        begin
          res = yield sp
          sp.success unless sp.stopped?
          res
        rescue ex
          sp.fail(ex.message) unless sp.stopped?
          raise ex
        ensure
          sp.stop unless sp.stopped?
        end
      end

      def start : Nil
        return if @running
        @running = true
        @driver.hide_cursor

        spawn do
          while @running
            frame = FRAMES[@frame_idx % FRAMES.size]
            @frame_idx += 1

            styled_frame = Style.new.bold.fg(:cyan).render(frame)
            @driver.write("\r\e[2K#{styled_frame} #{@text}")
            @driver.flush
            sleep 80.milliseconds
          end
        end
      end

      def stopped? : Bool
        !@running
      end

      def stop : Nil
        return unless @running
        @running = false
        @driver.show_cursor
        @driver.write("\r\e[2K")
        @driver.flush
      end

      def success(msg : String? = nil) : Nil
        stop
        display_msg = msg || @text
        mark = Style.new.bold.fg(:green).render("✓")
        @driver.write("#{mark} #{display_msg}\n")
        @driver.flush
      end

      def fail(msg : String? = nil) : Nil
        stop
        display_msg = msg || @text
        mark = Style.new.bold.fg(:red).render("✗")
        @driver.write("#{mark} #{display_msg}\n")
        @driver.flush
      end

      def warn(msg : String? = nil) : Nil
        stop
        display_msg = msg || @text
        mark = Style.new.bold.fg(:yellow).render("!")
        @driver.write("#{mark} #{display_msg}\n")
        @driver.flush
      end
    end
  end
end
