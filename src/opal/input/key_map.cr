require "../terminal/ansi_parser"

module Opal
  module Input
    # Declarative key binding and shortcut dispatch DSL.
    class KeyMap
      alias KeyAction = Terminal::KeyEvent -> Nil
      alias CharAction = Char -> Nil

      @bindings = [] of {Array(String), KeyAction}
      @char_handlers = [] of CharAction
      @catch_all_handlers = [] of KeyAction

      # Registers an action for one or more key descriptors (e.g. "ctrl+c", "q", "enter", "up")
      def on(*keys : String, &block : Terminal::KeyEvent -> Nil) : self
        @bindings << {keys.to_a, block}
        self
      end

      # Convenience overload when block takes 0 parameters
      def on(*keys : String, &block : -> Nil) : self
        action = ->(_ev : Terminal::KeyEvent) { block.call; nil }
        @bindings << {keys.to_a, action}
        self
      end

      # Registers a handler for any printable character input
      def on_char(&block : Char -> Nil) : self
        @char_handlers << block
        self
      end

      # Registers a catch-all handler for any unhandled key
      def on_any(&block : Terminal::KeyEvent -> Nil) : self
        @catch_all_handlers << block
        self
      end

      # Dispatches a KeyEvent through the registered key bindings.
      # Returns true if a binding matched and was executed, false otherwise.
      def handle(event : Terminal::KeyEvent) : Bool
        @bindings.each do |keys, action|
          if keys.any? { |k| event.matches?(k) }
            action.call(event)
            return true
          end
        end

        if ch = event.char
          if ch >= ' ' && !event.ctrl? && !event.alt? && !@char_handlers.empty?
            @char_handlers.each(&.call(ch))
            return true
          end
        end

        unless @catch_all_handlers.empty?
          @catch_all_handlers.each(&.call(event))
          return true
        end

        false
      end
    end
  end

  # Convenience DSL builder for key bindings
  def self.on_key(&block : Input::KeyMap -> Nil) : Input::KeyMap
    km = Input::KeyMap.new
    block.call(km)
    km
  end
end
