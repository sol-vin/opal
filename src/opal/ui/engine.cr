require "./control"

module Opal
  module UI
    # Focus coordinator and input router for interactive `Control` instances.
    # Coordinates Tab / Shift+Tab focus navigation, dispatches keyboard and mouse events
    # to the active control, and provides synthetic event injection for automated testing and puppeting.
    class Engine
      property controls : Array(Control)
      property focused_index : Int32 = 0
      property? tab_navigation : Bool = true
      property on_focus_change : Proc(Control?, Control?, Nil)? = nil

      def initialize(controls : Enumerable(Control) = [] of Control)
        @controls = [] of Control
        controls.each { |c| @controls << c }
        update_focus
      end

      # Adds a control to the engine. If it's the first control, it receives focus.
      def add(control : Control) : self
        @controls << control
        update_focus if @controls.size == 1
        self
      end

      # Removes a control from the engine and adjusts the active focus.
      def remove(control : Control) : self
        @controls.delete(control)
        @focused_index = @focused_index.clamp(0, Math.max(0, @controls.size - 1))
        update_focus
        self
      end

      # Returns the currently focused control, if any.
      def focused_control : Control?
        @controls[@focused_index]?
      end

      # Moves focus to the given control.
      def focus(control : Control) : self
        if idx = @controls.index(control)
          focus_at(idx)
        end
        self
      end

      # Moves focus to the control at the specified index.
      def focus_at(index : Int32) : self
        return self if @controls.empty?
        old_ctrl = focused_control
        @focused_index = index.clamp(0, @controls.size - 1)
        update_focus
        new_ctrl = focused_control
        if old_ctrl != new_ctrl
          @on_focus_change.try(&.call(old_ctrl, new_ctrl))
        end
        self
      end

      # Cycles focus forward to the next control.
      def focus_next : self
        return self if @controls.empty?
        next_idx = (@focused_index + 1) % @controls.size
        focus_at(next_idx)
      end

      # Cycles focus backward to the previous control.
      def focus_prev : self
        return self if @controls.empty?
        prev_idx = (@focused_index - 1 + @controls.size) % @controls.size
        focus_at(prev_idx)
      end

      # Blurs all controls (unsets focused? on all).
      def blur : self
        old_ctrl = focused_control
        @controls.each { |c| c.focused = false }
        @focused_index = -1
        if old_ctrl
          @on_focus_change.try(&.call(old_ctrl, nil))
        end
        self
      end

      private def update_focus : Nil
        @controls.each_with_index do |ctrl, idx|
          ctrl.focused = (idx == @focused_index)
        end
      end

      # Dispatches a key event. Intercepts Tab / Shift+Tab for navigation if enabled,
      # otherwise routes to the focused control.
      def handle_key(key : Terminal::KeyEvent) : Bool
        if @tab_navigation && @controls.size > 1
          if (key.name == "tab" && !key.shift?) || (key.char == '\t' && !key.shift?)
            focus_next
            return true
          elsif key.name == "shift+tab" || key.name == "backtab" || ((key.name == "tab" || key.char == '\t') && key.shift?)
            focus_prev
            return true
          end
        end

        if active = focused_control
          active.handle_input(key)
        else
          false
        end
      end

      # Dispatches a mouse event to the focused control.
      def handle_mouse(mouse : Terminal::MouseEvent) : Bool
        if active = focused_control
          active.handle_input(mouse)
        else
          false
        end
      end

      # General input event router (dispatches KeyEvent or MouseEvent).
      def handle_input(event : InputEvent) : Bool
        case event
        when Terminal::KeyEvent
          handle_key(event)
        when Terminal::MouseEvent
          handle_mouse(event)
        else
          false
        end
      end

      # Injects a synthetic key event for automated scripting or testing.
      def send_key(name : String, char : Char? = nil, ctrl : Bool = false, alt : Bool = false, shift : Bool = false) : Bool
        ev = Terminal::KeyEvent.new(name, char, ctrl: ctrl, alt: alt, shift: shift)
        handle_key(ev)
      end

      # Injects a synthetic mouse event for automated scripting or testing.
      def send_mouse(
        x : Int32,
        y : Int32,
        button : Terminal::MouseButton = Terminal::MouseButton::Left,
        action : Terminal::MouseAction = Terminal::MouseAction::Press,
        ctrl : Bool = false,
        alt : Bool = false,
        shift : Bool = false,
      ) : Bool
        ev = Terminal::MouseEvent.new(x, y, button, action, ctrl: ctrl, alt: alt, shift: shift)
        handle_mouse(ev)
      end

      # Attaches a puppeting hook to a managed control.
      def puppet(control : Control, &block : Control, InputEvent -> Bool) : self
        control.puppet(&block)
        self
      end

      # Executes an arbitrary mutation step on the currently focused control.
      def puppet_step(&block : Control -> Nil) : self
        if active = focused_control
          block.call(active)
        end
        self
      end
    end
  end
end
