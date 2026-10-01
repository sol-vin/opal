require "./element"
require "./control"
require "./buffer"
require "../terminal"

module Opal
  module UI
    alias ModalResult = String | Bool | Int32 | Float64 | Symbol | Nil

    # Base application screen inspired by Python Textual's Screen.
    # Manages local key bindings, root element tree, and lifecycle callbacks.
    class Screen < Control
      property name : String
      property title : String?
      property root : Element?
      property? mounted : Bool = false

      def initialize(@name : String, @title : String? = nil, @root : Element? = nil)
        super()
      end

      # Called when the screen is pushed onto the active screen stack
      def on_mount : Nil
        @mounted = true
      end

      # Called when the screen is removed from the active screen stack
      def on_unmount : Nil
        @mounted = false
      end

      def on_resize(width : Int32, height : Int32) : Nil
      end

      def handle_key(event : Terminal::KeyEvent) : Bool
        if (r = @root).is_a?(Control)
          r.handle_key(event)
        else
          false
        end
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        if (r = @root).is_a?(Control)
          r.handle_mouse(event)
        else
          false
        end
      end

      def children : Array(Element)
        if r = @root
          [r]
        else
          [] of Element
        end
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        if r = @root
          r.preferred_size(available_w, available_h)
        else
          {available_w, available_h}
        end
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0
        if r = @root
          r.render(buffer, x, y, width, height)
        end
      end
    end

    # Modal Screen inspired by Python Textual's ModalScreen.
    # Automatically dims/blurs the underlying screen, traps keyboard/mouse focus,
    # and returns a typed dismissal result back to the calling screen.
    class ModalScreen < Screen
      property? dim_backdrop : Bool = true
      property on_dismiss : Proc(ModalResult, Nil)? = nil
      property? dismissed : Bool = false

      def initialize(
        name : String = "modal",
        title : String? = nil,
        root : Element? = nil,
        @dim_backdrop : Bool = true,
      )
        super(name, title, root)
      end

      # Dismisses the modal screen and passes result to completion callback
      def dismiss(result : ModalResult = nil) : Nil
        return if @dismissed
        @dismissed = true
        @on_dismiss.try(&.call(result))
      end

      def handle_key(event : Terminal::KeyEvent) : Bool
        if event.name == "escape"
          dismiss(nil)
          return true
        end

        super(event)
      end
    end
  end
end
