require "./screen"

module Opal
  module Terminal
    # Manages terminal raw mode with guaranteed restoration guards.
    class RawMode
      @@active : Bool = false
      @@installed_at_exit : Bool = false

      # Executes the given block with the terminal in raw mode, restoring cooked mode afterwards.
      def self.run(&)
        return yield if @@active

        ensure_at_exit_handler
        @@active = true

        begin
          STDIN.raw do
            yield
          end
        ensure
          @@active = false
          # Ensure cursor is visible and normal mode restored
          STDOUT.print Screen::SHOW_CURSOR + Screen::RESET_FORMAT
          STDOUT.flush
        end
      end

      # Installs an at_exit cleanup hook once to prevent leaving user terminal in raw mode
      private def self.ensure_at_exit_handler : Nil
        return if @@installed_at_exit
        @@installed_at_exit = true

        at_exit do
          if @@active
            STDOUT.print Screen::SHOW_CURSOR + Screen::EXIT_ALT_BUFFER + Screen::DISABLE_MOUSE + Screen::RESET_FORMAT
            STDOUT.flush
            STDIN.cooked! rescue nil
          end
        end
      end
    end
  end
end
