require "./msg"

module Opal
  module TEA
    # Represents an asynchronous side-effect or command in The Elm Architecture.
    class Cmd
      getter? quit : Bool = false
      getter actions : Array(-> Msg?)

      def initialize(actions : Array(-> Msg?) = [] of (-> Msg?), @quit : Bool = false)
        @actions = actions
      end

      # Empty command doing nothing
      def self.none : Cmd
        new
      end

      # Command that requests exiting the application loop
      def self.quit : Cmd
        new(quit: true)
      end

      # Creates a command from a single background action returning a message
      def self.perform(&block : -> Msg?) : Cmd
        new([block])
      end

      # Combines multiple commands into a single batched command
      def self.batch(cmds : Array(Cmd)) : Cmd
        actions = [] of (-> Msg?)
        quit_requested = false

        cmds.each do |c|
          actions.concat(c.actions)
          quit_requested = true if c.quit?
        end

        new(actions, quit: quit_requested)
      end

      def self.batch(*cmds : Cmd) : Cmd
        batch(cmds.to_a)
      end

      # Produces a command that waits *interval* and then emits the message returned by *block*
      def self.tick(interval : Time::Span, &block : Time -> Msg) : Cmd
        perform do
          sleep interval
          block.call(Time.local)
        end
      end
    end
  end
end
