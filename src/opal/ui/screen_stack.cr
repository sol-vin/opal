require "./screen"
require "./buffer"
require "../terminal"

module Opal
  module UI
    # Screen stack orchestrator inspired by Python Textual's Screen Stack.
    # Manages navigation flow, modal dialog layering, backdrop dimming,
    # and dismissal callbacks.
    class ScreenStack
      getter stack : Array(Screen)

      def initialize(initial_screen : Screen? = nil)
        @stack = [] of Screen
        if s = initial_screen
          push_screen(s)
        end
      end

      # Returns the currently focused top-of-stack screen
      def active_screen : Screen?
        @stack.last?
      end

      def size : Int32
        @stack.size
      end

      def empty? : Bool
        @stack.empty?
      end

      # Pushes a new screen onto the stack with optional dismissal callback
      def push_screen(screen : Screen, &callback : ModalResult -> Nil) : Screen
        if screen.is_a?(ModalScreen)
          screen.on_dismiss = ->(res : ModalResult) {
            callback.call(res)
            pop_screen if @stack.last? == screen
            nil
          }
        end
        @stack << screen
        screen.on_mount
        screen
      end

      # Pushes a screen without a dismissal block
      def push_screen(screen : Screen) : Screen
        if screen.is_a?(ModalScreen)
          screen.on_dismiss = ->(res : ModalResult) {
            pop_screen if @stack.last? == screen
            nil
          }
        end
        @stack << screen
        screen.on_mount
        screen
      end

      # Pops and unmounts the active screen
      def pop_screen : Screen?
        return nil if @stack.empty?
        popped = @stack.pop
        popped.on_unmount
        popped
      end

      # Replaces entire stack or top screen with a new screen
      def switch_screen(screen : Screen) : Screen
        pop_screen unless @stack.empty?
        push_screen(screen)
      end

      def handle_key(event : Terminal::KeyEvent) : Bool
        if act = active_screen
          handled = act.handle_key(event)
          # Check if modal was dismissed during key handling
          if act.is_a?(ModalScreen) && act.dismissed?
            pop_screen if @stack.last? == act
          end
          handled
        else
          false
        end
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        if act = active_screen
          handled = act.handle_mouse(event)
          if act.is_a?(ModalScreen) && act.dismissed?
            pop_screen if @stack.last? == act
          end
          handled
        else
          false
        end
      end

      # Renders the screen stack with automatic modal backdrop compositing
      def render(buffer : Buffer, x : Int32 = 0, y : Int32 = 0, width : Int32 = buffer.width, height : Int32 = buffer.height) : Nil
        return if @stack.empty? || width <= 0 || height <= 0

        top = @stack.last
        if top.is_a?(ModalScreen) && @stack.size >= 2
          # 1. Render underlying base screen
          base = @stack[@stack.size - 2]
          base.render(buffer, x, y, width, height)

          # 2. Dim backdrop if requested
          buffer.dim_all if top.dim_backdrop?

          # 3. Render modal screen over dimmed base
          top.render(buffer, x, y, width, height)
        else
          top.render(buffer, x, y, width, height)
        end
      end
    end
  end
end
