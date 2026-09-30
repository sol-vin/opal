require "../terminal/ansi_parser"

module Opal
  module UI
    alias InputEvent = Terminal::KeyEvent | Terminal::MouseEvent

    # Module that equips UI components with per-control input lifecycle hooks,
    # custom input overrides, and code puppeting capabilities.
    module InputHookable
      property? focused : Bool = false
      property? custom_inputs : Bool = false
      property? fallback_to_defaults : Bool = true
      property input_hook : Proc(InputEvent, Bool)? = nil
      property default_input_proc : Proc(InputEvent, Bool)? = nil

      # Lifecycle hook: Configures default keyboard and mouse behaviors.
      # May be overridden by subclasses to establish or reset component-specific default input bindings.
      def setup_default_inputs : Nil
        @default_input_proc = ->(ev : InputEvent) : Bool {
          case ev
          when Terminal::KeyEvent
            handle_key(ev)
          when Terminal::MouseEvent
            handle_mouse(ev)
          else
            false
          end
        }
      end

      # Attaches a custom input hook to this control.
      # The block receives `self` (strongly typed to the control class) and the `InputEvent`.
      # Returning `true` consumes the event. Returning `false` allows fallback to default inputs
      # (if `fallback_to_defaults?` is true).
      def on_input(&block : self, InputEvent -> Bool) : self
        @input_hook = ->(ev : InputEvent) { block.call(self, ev) }
        @custom_inputs = true
        self
      end

      # Programmatically puppet this control from code. Alias for `on_input`.
      def puppet(&block : self, InputEvent -> Bool) : self
        on_input(&block)
      end

      # Enables or disables custom input processing.
      def use_custom_inputs!(enabled : Bool = true) : self
        @custom_inputs = enabled
        self
      end

      # Sets whether unhandled events in custom input hooks fall back to standard default inputs.
      def fallback_to_defaults!(enabled : Bool = true) : self
        @fallback_to_defaults = enabled
        self
      end

      # Clears custom hooks and reinitializes default input bindings.
      def reset_inputs : self
        @input_hook = nil
        @custom_inputs = false
        @fallback_to_defaults = true
        setup_default_inputs
        self
      end

      # Routes an incoming input event through custom hooks or default handlers.
      def handle_input(event : InputEvent) : Bool
        if @custom_inputs && (hook = @input_hook)
          handled = hook.call(event)
          return true if handled
        end

        if @fallback_to_defaults
          handle_default_input(event)
        else
          false
        end
      end

      # Executes the default input logic for this control.
      def handle_default_input(event : InputEvent) : Bool
        if def_proc = @default_input_proc
          return def_proc.call(event)
        end

        case event
        when Terminal::KeyEvent
          handle_key(event)
        when Terminal::MouseEvent
          handle_mouse(event)
        else
          false
        end
      end

      # Default key event handler. Override in subclasses if not using @default_input_proc.
      def handle_key(key : Terminal::KeyEvent) : Bool
        false
      end

      # Default mouse event handler. Override in subclasses if not using @default_input_proc.
      def handle_mouse(event : Terminal::MouseEvent) : Bool
        false
      end
    end
  end
end
